import SwiftUI
import AVFoundation
import PhotosUI
import SwiftData
import Combine

struct ScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(KnowledgeBaseService.self) private var knowledgeService
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = ScannerViewModel()

    let onComplete: (Ingredient, [Recipe]) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                CameraPreview(session: viewModel.captureSession)
                    .ignoresSafeArea()
                    .overlay(scannerOverlay)

                VStack {
                    Spacer()
                    bottomBar
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
            .onAppear { viewModel.startSession() }
            .onDisappear { viewModel.stopSession() }
            .onReceive(NotificationCenter.default.publisher(for: .photoCaptured)) { notif in
                guard let imageData = notif.object as? Data else { return }
                Task { await handleCapturedImage(imageData) }
            }
            .overlay {
                if viewModel.isProcessing {
                    processingOverlay(
                        status: viewModel.processingStatus,
                        ingredient: viewModel.recognizedName
                    )
                }
            }
            .alert("无法识别", isPresented: $viewModel.showFallbackAlert) {
                Button("手动输入") { viewModel.showManualInput = true }
                Button("重试") { viewModel.retry() }
                Button("取消", role: .cancel) { dismiss() }
            } message: {
                Text(viewModel.alertMessage)
            }
            .sheet(isPresented: $viewModel.showPhotoPicker) {
                PhotoPicker { imageData in
                    await handleCapturedImage(imageData)
                }
            }
            .sheet(isPresented: $viewModel.showManualInput) {
                ManualInputView { ingredient, recipes in
                    onComplete(ingredient, recipes)
                    dismiss()
                }
            }
            // 识别成功 → 跳转结果页
            .navigationDestination(isPresented: $viewModel.showResult) {
                if let ingredient = viewModel.matchedIngredient {
                    ScanResultView(
                        ingredient: ingredient,
                        matchedRecipes: viewModel.matchedRecipes
                    )
                }
            }
        }
    }

    // MARK: - 扫描框

    private var scannerOverlay: some View {
        ZStack {
            Color.black.opacity(0.3).ignoresSafeArea()

            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8, 4]))
                .foregroundStyle(.white.opacity(0.8))
                .frame(width: 280, height: 280)

            VStack {
                Spacer()
                Text("将食材置于框内")
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .padding(.bottom, 120)
            }
        }
    }

    // MARK: - 处理中遮罩

    private func processingOverlay(status: String, ingredient: String?) -> some View {
        Color.black.opacity(0.6)
            .ignoresSafeArea()
            .overlay {
                VStack(spacing: 20) {
                    // 根据 modelStatus 显示不同图标
                    switch knowledgeService.recognitionService.modelStatus {
                    case .customModelLoaded:
                        Image(systemName: "cpu")
                            .font(.system(size: 40))
                            .foregroundStyle(.green)
                    case .usingVisionFallback:
                        Image(systemName: "eye")
                            .font(.system(size: 40))
                            .foregroundStyle(.blue)
                    }

                    ProgressView()
                        .scaleEffect(1.3)
                        .tint(.white)

                    Text(status)
                        .foregroundStyle(.white)
                        .font(.headline)

                    if let name = ingredient, !name.isEmpty {
                        Text("识别为：\(name)")
                            .foregroundStyle(.white.opacity(0.8))
                            .font(.subheadline)
                    }

                    Text("引擎：\(knowledgeService.recognitionService.modelStatus.description)")
                        .foregroundStyle(.white.opacity(0.5))
                        .font(.caption)
                }
                .padding(32)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                )
            }
    }

    // MARK: - 拍照按钮区

    private var bottomBar: some View {
        HStack(spacing: 40) {
            Button {
                viewModel.showPhotoPicker = true
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.title2)
                    Text("相册")
                        .font(.caption2)
                }
                .foregroundStyle(.white)
            }

            Button {
                viewModel.capturePhoto(delegate: PhotoCaptureDelegate.shared)
            } label: {
                Circle()
                    .strokeBorder(.white, lineWidth: 4)
                    .frame(width: 72, height: 72)
                    .overlay {
                        Circle()
                            .fill(.white)
                            .frame(width: 60, height: 60)
                    }
            }

            Button {
                viewModel.showManualInput = true
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "keyboard")
                        .font(.title2)
                    Text("手动")
                        .font(.caption2)
                }
                .foregroundStyle(.white)
            }
        }
        .padding(.bottom, 40)
    }

    // MARK: - 识别处理（拍照 & 相册共用）

    private func handleCapturedImage(_ imageData: Data) async {
        viewModel.isProcessing = true
        viewModel.processingStatus = "正在识别..."
        viewModel.recognizedName = nil

        // 调用识别管线
        let result = await knowledgeService.recognitionService.recognize(
            imageData: imageData,
            modelContext: modelContext
        )

        await MainActor.run {
            viewModel.isProcessing = false

            // 情况 1：识别到食材且有知识库匹配 → 匹配菜谱并跳转
            if let ingredient = result.matchedIngredient {
                let recipes = knowledgeService.recipeMatchService.matchRecipes(
                    having: [ingredient],
                    matchMode: .partial
                )
                viewModel.matchedIngredient = ingredient
                viewModel.matchedRecipes = recipes
                viewModel.showResult = true
                return
            }

            // 情况 2：有识别名但未匹配到知识库 → 提示新建
            if !result.ingredientName.isEmpty, result.confidence > 0.35 {
                viewModel.recognizedName = result.ingredientName
                viewModel.alertMessage = "识别到「\(result.ingredientName)」(\(Int(result.confidence * 100))%)，" +
                                         "但知识库中暂无此食材。要手动输入确认吗？"
                viewModel.showFallbackAlert = true
                return
            }

            // 情况 3：置信度过低 → 回退手动
            let candidateText = result.candidates.isEmpty
                ? ""
                : "\n可能的食材：\(result.candidates.prefix(3).joined(separator: "、"))"
            viewModel.alertMessage = "未能明确识别食材。" + candidateText
            viewModel.showFallbackAlert = true
        }
    }
}

// MARK: - ScannerViewModel

@Observable
final class ScannerViewModel {
    let captureSession = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var isSessionRunning = false

    // UI 状态
    var isProcessing = false
    var processingStatus = ""
    var recognizedName: String?
    var showFallbackAlert = false
    var alertMessage = ""
    var showPhotoPicker = false
    var showManualInput = false
    var showResult = false

    // 识别结果
    var matchedIngredient: Ingredient?
    var matchedRecipes: [Recipe] = []

    // MARK: - 会话管理

    func startSession() {
        guard !isSessionRunning else { return }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted { self.startSession() }
            }
            return
        case .denied, .restricted:
            alertMessage = "相机权限未开启，请前往设置开启"
            showFallbackAlert = true
            return
        default: break
        }

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else {
            alertMessage = "无法访问相机"
            showFallbackAlert = true
            return
        }

        captureSession.beginConfiguration()
        captureSession.sessionPreset = .photo

        if captureSession.canAddInput(input) { captureSession.addInput(input) }
        if captureSession.canAddOutput(photoOutput) { captureSession.addOutput(photoOutput) }

        // 开启自动对焦
        try? device.lockForConfiguration()
        if device.isFocusModeSupported(.continuousAutoFocus) {
            device.focusMode = .continuousAutoFocus
        }
        device.unlockForConfiguration()

        captureSession.commitConfiguration()

        DispatchQueue.global(qos: .userInitiated).async {
            self.captureSession.startRunning()
            self.isSessionRunning = true
        }
    }

    func stopSession() {
        guard isSessionRunning else { return }
        DispatchQueue.global(qos: .background).async {
            self.captureSession.stopRunning()
            self.isSessionRunning = false
        }
    }

    // MARK: - 拍摄按钮回调

    func capturePhoto(delegate: AVCapturePhotoCaptureDelegate) {
        guard isSessionRunning, !isProcessing else { return }

        let settings = AVCapturePhotoSettings()
        settings.flashMode = .auto

        // 拍照触觉反馈
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif

        photoOutput.capturePhoto(with: settings, delegate: delegate)
    }

    func retry() {
        showFallbackAlert = false
        alertMessage = ""
        recognizedName = nil
        capturedImageData = nil
    }
}

// MARK: - PhotoCaptureDelegate

/// 拍照委托：将 AVCapturePhoto 转为 Data，通过通知抛出给 ScannerView
final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    static let shared = PhotoCaptureDelegate()

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error {
            print("⚠️ 拍照失败: \(error.localizedDescription)")
            return
        }

        guard let imageData = photo.fileDataRepresentation() else {
            print("⚠️ 无法获取照片数据")
            return
        }

        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .photoCaptured,
                object: imageData
            )
        }
    }
}

extension Notification.Name {
    static let photoCaptured = Notification.Name("com.caidaizi.photoCaptured")
}

// MARK: - CameraPreview

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        guard let layer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer else { return }
        layer.frame = uiView.bounds
    }
}

// MARK: - PhotoPicker

struct PhotoPicker: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedItem: PhotosPickerItem?
    let onPick: (Data) async -> Void

    var body: some View {
        PhotosPicker(selection: $selectedItem, matching: .images) {
            Text("选择照片")
        }
        .onChange(of: selectedItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    await onPick(data)
                }
                dismiss()
            }
        }
    }
}

// MARK: - 手动输入

struct ManualInputView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(KnowledgeBaseService.self) private var knowledgeService
    @State private var searchText = ""
    @State private var searchResults: [Ingredient] = []

    let onComplete: (Ingredient, [Recipe]) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("输入食材名称...", text: $searchText)
                        .autocorrectionDisabled()
                        .onSubmit { performSearch() }

                    if !searchText.isEmpty {
                        Button { searchText = ""; searchResults = [] } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.background)
                        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
                )
                .padding()

                if searchResults.isEmpty && !searchText.isEmpty {
                    VStack(spacing: 16) {
                        ContentUnavailableView(
                            "未找到「\(searchText)」",
                            systemImage: "magnifyingglass",
                            description: Text("知识库中暂无此食材")
                        )
                        Button("新建食材并查看可做的菜") {
                            let ingredient = knowledgeService.createIngredient(name: searchText)
                            let recipes = knowledgeService.recipeMatchService.matchRecipes(
                                having: [ingredient],
                                matchMode: .partial
                            )
                            onComplete(ingredient, recipes)
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                    }
                } else {
                    List {
                        ForEach(searchResults) { ingredient in
                            Button {
                                let recipes = knowledgeService.recipeMatchService.matchRecipes(
                                    having: [ingredient],
                                    matchMode: .partial
                                )
                                onComplete(ingredient, recipes)
                                dismiss()
                            } label: {
                                HStack {
                                    Text(ingredient.emoji ?? "🥬")
                                        .font(.title2)
                                    VStack(alignment: .leading) {
                                        Text(ingredient.name)
                                            .foregroundStyle(.primary)
                                        if let category = ingredient.category {
                                            Text(category.name)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("输入食材")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }

    private func performSearch() {
        searchResults = knowledgeService.searchIngredients(query: searchText)
    }
}

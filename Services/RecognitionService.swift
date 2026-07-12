import Foundation
import SwiftUI
import Observation
import SwiftData
import Vision
import CoreML

// MARK: - 食材识别服务
///
/// 三级识别策略（自动降级）：
///   1. 自定义 CoreML 食材分类器 → 最高精度，需训练
///   2. Apple Vision 内置分类器 → 通用物体识别，作为后备
///   3. 回退到手动输入 → 无模型 / 低置信度时兜底
///
@Observable
final class RecognitionService {

    enum RecognitionEngine {
        case coreML      // 自定义食材模型
        case vision      // Vision 内置分类
        case barcode     // 条码扫描
        case manual      // 手动输入
    }

    enum RecognitionState {
        case idle
        case processing
        case success(RecognitionResult)
        case fallbackToManual   // 需要手动输入
        case error(String)
    }

    var currentEngine: RecognitionEngine = .coreML
    var state: RecognitionState = .idle
    var isProcessing: Bool { if case .processing = state { true } else { false } }

    // MARK: - 模型管理

    /// 尝试加载自定义食材分类 CoreML 模型
    /// 文件名应为 "IngredientClassifier.mlmodelc"（编译后的模型）
    private var customModel: VNCoreMLModel? = {
        guard let modelURL = Bundle.main.url(
            forResource: "IngredientClassifier",
            withExtension: "mlmodelc"
        ) else {
            print("ℹ️ 未找到自定义食材模型，将使用 Vision 内置分类器作为后备")
            return nil
        }

        do {
            let mlModel = try MLModel(contentsOf: modelURL)
            let vnModel = try VNCoreMLModel(for: mlModel)
            print("✅ 已加载自定义食材分类模型")
            return vnModel
        } catch {
            print("⚠️ 自定义模型加载失败: \(error.localizedDescription)")
            return nil
        }
    }()

    // MARK: - Vision 类别 → 食材名映射
    /// 将 Vision 内置分类器的标签映射到我们的食材名
    /// 覆盖常见果蔬肉类的英文标签
    private let visionLabelMapping: [String: (chineseName: String, confidenceBoost: Float)] = [
        // 蔬菜
        "tomato": ("番茄", 0.05),
        "potato": ("土豆", 0.05),
        "onion": ("洋葱", 0.05),
        "garlic": ("大蒜", 0.05),
        "ginger": ("生姜", 0.05),
        "carrot": ("胡萝卜", 0.05),
        "broccoli": ("西兰花", 0.05),
        "cabbage": ("白菜", 0.05),
        "bell pepper": ("青椒", 0.05),
        "eggplant": ("茄子", 0.05),
        "cucumber": ("黄瓜", 0.05),
        "mushroom": ("香菇", 0.05),
        "corn": ("玉米", 0.05),
        "celery": ("芹菜", 0.05),
        "lettuce": ("生菜", 0.05),
        "spinach": ("菠菜", 0.05),
        "cauliflower": ("花菜", 0.05),
        "green bean": ("豆角", 0.05),
        "pea": ("豌豆", 0.05),
        "pumpkin": ("南瓜", 0.05),
        "radish": ("白萝卜", 0.05),
        "turnip": ("白萝卜", 0.05),
        "yam": ("山药", 0.05),
        "lotus root": ("莲藕", 0.05),
        "bamboo shoot": ("竹笋", 0.05),

        // 水果
        "lemon": ("柠檬", 0.05),
        "apple": ("苹果", 0.05),
        "banana": ("香蕉", 0.05),
        "orange": ("橙子", 0.05),
        "grape": ("葡萄", 0.05),
        "pear": ("梨", 0.05),
        "peach": ("桃子", 0.05),
        "strawberry": ("草莓", 0.05),
        "watermelon": ("西瓜", 0.05),
        "mango": ("芒果", 0.05),
        "pineapple": ("菠萝", 0.05),
        "kiwi": ("猕猴桃", 0.05),
        "cherry": ("樱桃", 0.05),
        "blueberry": ("蓝莓", 0.05),
        "coconut": ("椰子", 0.05),

        // 肉类
        "pork": ("猪肉", 0.05),
        "beef": ("牛肉", 0.05),
        "chicken": ("鸡肉", 0.05),
        "lamb": ("羊肉", 0.05),
        "duck": ("鸭肉", 0.05),
        "fish": ("鱼", 0.05),
        "shrimp": ("虾", 0.05),
        "crab": ("蟹", 0.05),
        "squid": ("鱿鱼", 0.05),
        "clam": ("蛤蜊", 0.05),
        "egg": ("鸡蛋", 0.05),
        "tofu": ("豆腐", 0.05),

        // 五谷
        "rice": ("大米", 0.05),
        "noodle": ("面条", 0.05),
        "bread": ("面包", 0.05),
        "pasta": ("意面", 0.05),
    ]

    // MARK: - 识别结果

    struct RecognitionResult: Equatable {
        let ingredientName: String
        let confidence: Float
        let matchedIngredient: Ingredient?
        let candidates: [String]        // 备选食材名（置信度较低但仍可能）

        static func == (lhs: RecognitionResult, rhs: RecognitionResult) -> Bool {
            lhs.ingredientName == rhs.ingredientName &&
            lhs.confidence == rhs.confidence &&
            lhs.matchedIngredient?.id == rhs.matchedIngredient?.id
        }
    }

    // MARK: - 核心识别

    /// 识别图片中的食材
    /// - Parameters:
    ///   - imageData: 图片数据
    ///   - modelContext: 用于查询知识库做名称匹配
    /// - Returns: 识别结果；若所有策略均失败则返回空结果并标记 fallbackToManual
    func recognize(imageData: Data, modelContext: ModelContext? = nil) async -> RecognitionResult {
        state = .processing
        defer {
            if case .processing = state {
                state = .fallbackToManual
            }
        }

        guard let cgImage = cgImage(from: imageData) else {
            state = .error("无法解析图片")
            return RecognitionResult(ingredientName: "", confidence: 0, matchedIngredient: nil, candidates: [])
        }

        // 策略 1：自定义 CoreML 模型
        if let model = customModel {
            if let result = await classifyWithCustomModel(cgImage, model: model, context: modelContext) {
                let finalResult = matchToKnowledgeBase(result, context: modelContext)
                state = .success(finalResult)

                // 置信度过低 → 让用户确认
                if finalResult.confidence < 0.4 {
                    state = .fallbackToManual
                }
                return finalResult
            }
        }

        // 策略 2：Vision 内置分类器
        if let visionResult = await classifyWithVision(cgImage, context: modelContext) {
            let finalResult = matchToKnowledgeBase(visionResult, context: modelContext)
            state = .success(finalResult)

            if finalResult.confidence < 0.3 {
                state = .fallbackToManual
            }
            return finalResult
        }

        // 策略 3：全部失败 → 手动输入
        state = .fallbackToManual
        return RecognitionResult(ingredientName: "", confidence: 0, matchedIngredient: nil, candidates: [])
    }

    // MARK: - 策略 1：自定义 CoreML 分类

    private func classifyWithCustomModel(
        _ cgImage: CGImage,
        model: VNCoreMLModel,
        context: ModelContext?
    ) async -> RecognitionResult? {

        await withCheckedContinuation { continuation in
            let request = VNCoreMLRequest(model: model) { request, error in
                guard error == nil,
                      let results = request.results as? [VNClassificationObservation],
                      let top = results.first,
                      top.confidence > 0.2 else {
                    continuation.resume(returning: nil)
                    return
                }

                let name = top.identifier
                let candidates = results.prefix(5).map(\.identifier)
                let result = RecognitionResult(
                    ingredientName: name,
                    confidence: top.confidence,
                    matchedIngredient: nil,
                    candidates: candidates
                )
                continuation.resume(returning: result)
            }

            request.imageCropAndScaleOption = .centerCrop

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    print("⚠️ CoreML 推理失败: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    // MARK: - 策略 2：Vision 内置分类器

    private func classifyWithVision(
        _ cgImage: CGImage,
        context: ModelContext?
    ) async -> RecognitionResult? {

        await withCheckedContinuation { continuation in
            let request = VNClassifyImageRequest { request, error in
                guard error == nil,
                      let results = request.results as? [VNClassificationObservation],
                      !results.isEmpty else {
                    continuation.resume(returning: nil)
                    return
                }

                // 收集所有可能的食材识别结果
                var allCandidates: [(name: String, confidence: Float)] = []

                for observation in results where observation.confidence > 0.15 {
                    let label = observation.identifier.lowercased()

                    // 检查是否在我们的映射表中
                    if let mapping = visionLabelMapping[label] {
                        allCandidates.append((
                            name: mapping.chineseName,
                            confidence: observation.confidence + mapping.confidenceBoost
                        ))
                    } else {
                        // 未映射的标签：尝试部分匹配
                        for (key, mapping) in visionLabelMapping {
                            if label.contains(key) || key.contains(label) {
                                allCandidates.append((
                                    name: mapping.chineseName,
                                    confidence: observation.confidence * 0.8 + mapping.confidenceBoost
                                ))
                                break
                            }
                        }
                    }
                }

                // 按置信度排序
                allCandidates.sort { $0.confidence > $1.confidence }

                guard let top = allCandidates.first, top.confidence > 0.2 else {
                    continuation.resume(returning: nil)
                    return
                }

                let candidates = allCandidates.prefix(5).map(\.name)
                let result = RecognitionResult(
                    ingredientName: top.name,
                    confidence: top.confidence,
                    matchedIngredient: nil,
                    candidates: candidates
                )
                continuation.resume(returning: result)
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    print("⚠️ Vision 分类失败: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    // MARK: - 名称匹配到知识库

    /// 将识别出的食材名称匹配到知识库中的 Ingredient
    private func matchToKnowledgeBase(
        _ result: RecognitionResult,
        context: ModelContext?
    ) -> RecognitionResult {
        guard let context else { return result }

        // 精确匹配
        if let ingredient = searchIngredient(name: result.ingredientName, in: context) {
            return RecognitionResult(
                ingredientName: result.ingredientName,
                confidence: result.confidence,
                matchedIngredient: ingredient,
                candidates: result.candidates
            )
        }

        // 别名匹配
        for candidate in result.candidates {
            if let ingredient = searchIngredient(name: candidate, in: context) {
                return RecognitionResult(
                    ingredientName: ingredient.name,
                    confidence: result.confidence * 0.9,
                    matchedIngredient: ingredient,
                    candidates: result.candidates
                )
            }
        }

        // 模糊匹配：用知识库里所有食材名做相似度比对
        let descriptor = FetchDescriptor<Ingredient>(sortBy: [SortDescriptor(\.name)])
        if let allIngredients = try? context.fetch(descriptor) {
            for ingredient in allIngredients {
                if ingredient.name.contains(result.ingredientName) ||
                   result.ingredientName.contains(ingredient.name) {
                    return RecognitionResult(
                        ingredientName: ingredient.name,
                        confidence: result.confidence * 0.85,
                        matchedIngredient: ingredient,
                        candidates: result.candidates
                    )
                }
            }
        }

        return result
    }

    // MARK: - 通过食材名称搜索知识库

    func searchIngredient(name: String, in context: ModelContext) -> Ingredient? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let predicate = #Predicate<Ingredient> { ingredient in
            ingredient.name.localizedStandardContains(trimmed) ||
            ingredient.aliases.contains(trimmed)
        }

        let descriptor = FetchDescriptor<Ingredient>(predicate: predicate)
        return try? context.fetch(descriptor).first
    }

    // MARK: - CGImage 转换

    private func cgImage(from data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return nil
        }
        return cgImage
    }

    // MARK: - 获取模型状态

    var modelStatus: ModelStatus {
        if customModel != nil { return .customModelLoaded }
        return .usingVisionFallback
    }

    enum ModelStatus: CustomStringConvertible {
        case customModelLoaded
        case usingVisionFallback

        var description: String {
            switch self {
            case .customModelLoaded: "自定义食材模型"
            case .usingVisionFallback: "Vision 内置分类器（后备）"
            }
        }
    }
}

// MARK: - 菜谱匹配服务

@Observable
final class RecipeMatchService {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// 根据食材列表匹配能做的菜
    /// - Parameters:
    ///   - ingredients: 手头有的食材
    ///   - matchMode: 匹配模式（全部匹配 / 部分匹配）
    /// - Returns: 按匹配度排序的菜谱
    func matchRecipes(
        having ingredients: [Ingredient],
        matchMode: MatchMode = .partial
    ) -> [Recipe] {
        let ingredientIDs = Set(ingredients.map(\.id))

        let descriptor = FetchDescriptor<Recipe>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        guard let allRecipes = try? modelContext.fetch(descriptor) else { return [] }

        return allRecipes.compactMap { recipe in
            let requiredIDs = Set(
                recipe.ingredients
                    .filter { !$0.isOptional }
                    .map(\.ingredient.id)
            )
            let matchCount = requiredIDs.intersection(ingredientIDs).count
            let totalRequired = requiredIDs.count

            guard totalRequired > 0 else { return nil }

            switch matchMode {
            case .exact:
                guard requiredIDs.isSubset(of: ingredientIDs) else { return nil }
            case .partial:
                guard matchCount >= max(1, totalRequired / 2) else { return nil }
            }

            let matchRate = Double(matchCount) / Double(totalRequired)
            return (recipe, matchRate)
        }
        .sorted { $0.1 > $1.1 }
        .map(\.0)
    }

    enum MatchMode {
        case exact   // 全部材料都有
        case partial // 有至少一半就行
    }
}

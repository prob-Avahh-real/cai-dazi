import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(KnowledgeBaseService.self) private var knowledgeService
    @Environment(\.modelContext) private var modelContext

    @State private var ingredientCount = 0
    @State private var recipeCount = 0
    @State private var scanCount = 0
    @State private var favoriteCount = 0

    @State private var showAddIngredient = false
    @State private var showAddTag = false

    var body: some View {
        NavigationStack {
            List {
                // 数据总览
                Section {
                    statsGrid
                } header: {
                    Label("菜搭子数据", systemImage: "chart.bar")
                }

                // 快捷操作
                Section {
                    Button { showAddIngredient = true } label: {
                        Label("新增食材", systemImage: "carrot")
                    }
                    Button { showAddTag = true } label: {
                        Label("管理标签", systemImage: "tag")
                    }
                } header: {
                    Label("管理", systemImage: "gearshape")
                }

                // 动态扩展提示
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("知识库可伸缩", systemImage: "arrow.triangle.branch")
                            .font(.subheadline.weight(.medium))

                        Text("菜搭子的食材和菜谱都支持自定义字段，您可以随时为食材增加「产地」「挑选技巧」等信息。分类支持无限层级，标签自由创建。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Label("关于动态知识库", systemImage: "info.circle")
                }

                // CloudKit 同步状态
                Section {
                    cloudSyncStatus
                } header: {
                    Label("同步", systemImage: "icloud")
                }

                // 版本
                Section {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("我的")
            .onAppear { loadStats() }
            .sheet(isPresented: $showAddIngredient) {
                addIngredientSheet
            }
            .sheet(isPresented: $showAddTag) {
                addTagSheet
            }
        }
    }

    // MARK: - 统计

    private var statsGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
            statCard(icon: "carrot", value: "\(ingredientCount)", label: "食材")
            statCard(icon: "fork.knife", value: "\(recipeCount)", label: "菜谱")
            statCard(icon: "camera.viewfinder", value: "\(scanCount)", label: "扫描记录")
            statCard(icon: "heart", value: "\(favoriteCount)", label: "收藏")
        }
        .padding(.vertical, 8)
    }

    private func statCard(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.green)
            Text(value)
                .font(.title2.bold())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.green.opacity(0.05))
        )
    }

    // MARK: - 新增食材

    private var addIngredientSheet: some View {
        NavigationStack {
            Form {
                TextField("食材名称", text: .constant(""))
                TextField("别名（逗号分隔）", text: .constant(""))
                TextField("Emoji", text: .constant(""))
            }
            .navigationTitle("新增食材")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { showAddIngredient = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { showAddIngredient = false }
                }
            }
        }
    }

    // MARK: - 管理标签

    private var addTagSheet: some View {
        NavigationStack {
            List {
                let tags = knowledgeService.getAllTags()
                if tags.isEmpty {
                    Text("暂无标签")
                        .foregroundStyle(.secondary)
                }
                ForEach(tags) { tag in
                    HStack {
                        Circle()
                            .fill(Color(hex: tag.colorHex ?? "34C759"))
                            .frame(width: 12, height: 12)
                        Text(tag.name)
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        modelContext.delete(tags[index])
                    }
                }

                Button {
                    let _ = knowledgeService.createTag(name: "新标签")
                } label: {
                    Label("添加标签", systemImage: "plus")
                }
            }
            .navigationTitle("管理标签")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { showAddTag = false }
                }
            }
        }
    }

    private func loadStats() {
        ingredientCount = knowledgeService.getAllIngredients().count
        recipeCount = knowledgeService.getAllRecipes().count
        scanCount = knowledgeService.getScanHistory().count
        favoriteCount = knowledgeService.getFavoriteRecipes().count
    }

    // MARK: - CloudKit 同步状态

    private var cloudSyncStatus: some View {
        HStack {
            Image(systemName: "icloud.fill")
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 2) {
                Text("iCloud 同步")
                    .font(.subheadline)

                // SwiftData + CloudKit 状态检测：
                // 自动模式下，如果用户已登录 iCloud 且容器可用，SwiftData 会自动同步
                // 此处显示静态提示；实际同步状态由系统自动管理
                HStack(spacing: 4) {
                    Circle()
                        .fill(
                            FileManager.default.ubiquityIdentityToken != nil
                            ? Color.green : Color.secondary
                        )
                        .frame(width: 6, height: 6)

                    Text(
                        FileManager.default.ubiquityIdentityToken != nil
                        ? "已连接 · 自动同步中"
                        : "请在「设置 → Apple ID → iCloud」中登录以开启同步"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if FileManager.default.ubiquityIdentityToken != nil {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundStyle(.green)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Color from hex

extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch h.count {
        case 6:
            (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

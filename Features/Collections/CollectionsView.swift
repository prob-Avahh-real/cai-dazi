import SwiftUI

struct CollectionsView: View {
    @Environment(KnowledgeBaseService.self) private var knowledgeService
    @State private var favoriteRecipes: [Recipe] = []
    @State private var scanHistory: [ScanRecord] = []
    @State private var selectedTab: CollectionTab = .favorites

    enum CollectionTab: String, CaseIterable {
        case favorites = "收藏菜谱"
        case history = "扫描记录"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $selectedTab) {
                    ForEach(CollectionTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                .background(Color(.systemGroupedBackground))

                switch selectedTab {
                case .favorites:
                    favoritesList
                case .history:
                    historyList
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("收藏")
            .onAppear { loadData() }
        }
    }

    // MARK: - 收藏菜谱

    private var favoritesList: some View {
        Group {
            if favoriteRecipes.isEmpty {
                ContentUnavailableView(
                    "还没有收藏的菜谱",
                    systemImage: "heart",
                    description: Text("在菜谱详情页点击 ♡ 收藏")
                )
            } else {
                List {
                    ForEach(favoriteRecipes) { recipe in
                        NavigationLink {
                            RecipeDetailView(recipe: recipe)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(recipe.name)
                                    .font(.body)
                                HStack(spacing: 8) {
                                    Text(recipe.formattedCookingTime)
                                    Text("•")
                                        .foregroundStyle(.secondary)
                                    Text(recipe.difficultyLabel)
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            knowledgeService.toggleFavorite(recipe: favoriteRecipes[index])
                        }
                        loadData()
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    // MARK: - 扫描历史

    private var historyList: some View {
        Group {
            if scanHistory.isEmpty {
                ContentUnavailableView(
                    "还没有扫描记录",
                    systemImage: "camera.viewfinder",
                    description: Text("去首页扫一扫食材吧")
                )
            } else {
                List {
                    ForEach(scanHistory) { record in
                        NavigationLink {
                            if let ingredient = record.matchedIngredient {
                                ScanResultView(
                                    ingredient: ingredient,
                                    matchedRecipes: record.matchedRecipes
                                )
                            }
                        } label: {
                            HStack(spacing: 12) {
                                if let data = record.capturedImageData,
                                   let uiImage = UIImage(data: data) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .frame(width: 48, height: 48)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                } else {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(.green.opacity(0.1))
                                        .frame(width: 48, height: 48)
                                        .overlay {
                                            Text(record.matchedIngredient?.emoji ?? "🥬")
                                                .font(.title2)
                                        }
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(record.recognizedName)
                                        .font(.body.weight(.medium))
                                    HStack(spacing: 4) {
                                        Text(record.source.rawValue)
                                        Text("•")
                                        Text(record.scannedAt, style: .relative)
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }

                                Spacer()

                                if record.confidence > 0 {
                                    Text("\(Int(record.confidence * 100))%")
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(.green)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            knowledgeService.deleteIngredient(scanHistory[index].matchedIngredient)
                        }
                        loadData()
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private func loadData() {
        favoriteRecipes = knowledgeService.getFavoriteRecipes()
        scanHistory = knowledgeService.getScanHistory()
    }
}

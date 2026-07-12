import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(KnowledgeBaseService.self) private var knowledgeService
    @State private var showScanner = false
    @State private var showManualInput = false
    @State private var manualSearchText = ""
    @State private var scannedIngredient: Ingredient?
    @State private var matchedRecipes: [Recipe] = []
    @State private var showResult = false
    @State private var searchResult: Ingredient?

    /// 当季推荐
    private var seasonalIngredients: [Ingredient] {
        let month = Calendar.current.component(.month, from: Date())
        return knowledgeService.getSeasonalIngredients(month: month)
    }

    private var seasonalRecipes: [Recipe] {
        let month = Calendar.current.component(.month, from: Date())
        return knowledgeService.getSeasonalRecipes(month: month)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    scanEntrySection
                    seasonalSection
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("菜搭子")
            .fullScreenCover(isPresented: $showScanner) {
                ScannerView { ingredient, recipes in
                    scannedIngredient = ingredient
                    matchedRecipes = recipes
                    showResult = true
                }
            }
            .navigationDestination(isPresented: $showResult) {
                if let ingredient = scannedIngredient {
                    ScanResultView(
                        ingredient: ingredient,
                        matchedRecipes: matchedRecipes
                    )
                }
            }
        }
    }

    // MARK: - 顶部问候

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(timeBasedGreeting)
                .font(.title2.bold())
            Text("今天想做什么菜？")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 扫描入口

    private var scanEntrySection: some View {
        VStack(spacing: 16) {
            Button {
                showScanner = true
            } label: {
                VStack(spacing: 12) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 44))
                        .symbolEffect(.bounce, options: .repeat(2))
                    Text("扫一扫食材")
                        .font(.headline)
                    Text("拍一下食材，看看能做什么菜")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.green.gradient)
                        .shadow(color: .green.opacity(0.3), radius: 12, y: 4)
                )
                .foregroundStyle(.white)
            }

            // 手动输入
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("输入食材名称搜索...", text: $manualSearchText)
                    .autocorrectionDisabled()
                if !manualSearchText.isEmpty {
                    Button {
                        manualSearchText = ""
                        searchResult = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
                Button("搜索") {
                    searchIngredient()
                }
                .disabled(manualSearchText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.background)
                    .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
            )
        }
    }

    // MARK: - 当季推荐

    private var seasonalSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "leaf.fill")
                    .foregroundStyle(.green)
                Text("当季食材")
                    .font(.headline)
                Spacer()
                NavigationLink("查看全部") {
                    SeasonalIngredientListView()
                }
                .font(.subheadline)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(seasonalIngredients.prefix(10)) { ingredient in
                        NavigationLink {
                            IngredientDetailView(ingredient: ingredient)
                        } label: {
                            IngredientCard(ingredient: ingredient)
                        }
                    }
                }
            }

            if !seasonalRecipes.isEmpty {
                HStack {
                    Image(systemName: "fork.knife")
                        .foregroundStyle(.orange)
                    Text("当季推荐菜")
                        .font(.headline)
                    Spacer()
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(seasonalRecipes.prefix(10)) { recipe in
                            NavigationLink {
                                RecipeDetailView(recipe: recipe)
                            } label: {
                                RecipeCard(recipe: recipe)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private var timeBasedGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<6: return "🌙 夜深了"
        case 6..<9: return "🌅 早上好"
        case 9..<11: return "☀️ 上午好"
        case 11..<14: return "🌞 中午好"
        case 14..<17: return "🌤️ 下午好"
        case 17..<19: return "🌆 傍晚好"
        default: return "🌙 晚上好"
        }
    }

    private func searchIngredient() {
        let results = knowledgeService.searchIngredients(query: manualSearchText)
        searchResult = results.first
        if let ingredient = searchResult {
            scannedIngredient = ingredient
            matchedRecipes = []
            showResult = true
        }
    }
}

// MARK: - 食材卡片

struct IngredientCard: View {
    let ingredient: Ingredient

    var body: some View {
        VStack(spacing: 8) {
            Text(ingredient.emoji ?? "🥬")
                .font(.system(size: 36))
            Text(ingredient.name)
                .font(.caption.weight(.medium))
                .lineLimit(1)
        }
        .frame(width: 80, height: 90)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.background)
                .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
        )
    }
}

// MARK: - 菜谱卡片

struct RecipeCard: View {
    let recipe: Recipe

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(recipe.name)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.caption2)
                Text(recipe.formattedCookingTime)
                    .font(.caption2)
            }
            .foregroundStyle(.secondary)
        }
        .frame(width: 140, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.background)
                .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
        )
    }
}

// MARK: - 当季食材列表

struct SeasonalIngredientListView: View {
    @Environment(KnowledgeBaseService.self) private var knowledgeService

    var body: some View {
        let month = Calendar.current.component(.month, from: Date())
        let ingredients = knowledgeService.getSeasonalIngredients(month: month)

        List {
            ForEach(ingredients) { ingredient in
                NavigationLink {
                    IngredientDetailView(ingredient: ingredient)
                } label: {
                    HStack {
                        Text(ingredient.emoji ?? "🥬")
                            .font(.title2)
                        VStack(alignment: .leading) {
                            Text(ingredient.name)
                                .font(.body)
                            if let summary = ingredient.summary {
                                Text(summary)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("\(month)月当季食材")
    }
}

import SwiftUI
import SwiftData

struct KnowledgeBaseView: View {
    @Environment(KnowledgeBaseService.self) private var knowledgeService

    @State private var searchText = ""
    @State private var selectedTab: KBTab = .ingredients
    @State private var ingredients: [Ingredient] = []
    @State private var recipes: [Recipe] = []
    @State private var categories: [Category] = []

    enum KBTab: String, CaseIterable {
        case ingredients = "食材"
        case recipes = "菜谱"
        case categories = "分类"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 搜索栏
                searchBar

                // 分段
                Picker("", selection: $selectedTab) {
                    ForEach(KBTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                // 内容
                if searchText.isEmpty {
                    contentList
                } else {
                    searchResults
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("知识库")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        RecipeCreateView()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .onAppear { loadData() }
            .onChange(of: selectedTab) { _, _ in loadData() }
        }
    }

    // MARK: - 搜索

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("搜索食材或菜谱...", text: $searchText)
                .autocorrectionDisabled()
                .onSubmit { performSearch() }
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.background)
                .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
        )
        .padding()
    }

    // MARK: - 内容列表

    @ViewBuilder
    private var contentList: some View {
        switch selectedTab {
        case .ingredients:
            ingredientList
        case .recipes:
            recipeList
        case .categories:
            categoryList
        }
    }

    // MARK: - 食材列表

    private var ingredientList: some View {
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
                            if let category = ingredient.category {
                                Text(category.name)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    // MARK: - 菜谱列表

    private var recipeList: some View {
        List {
            ForEach(recipes) { recipe in
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
        }
        .listStyle(.plain)
    }

    // MARK: - 分类视图

    private var categoryList: some View {
        List {
            ForEach(categories) { category in
                NavigationLink {
                    CategoryDetailView(category: category)
                } label: {
                    HStack {
                        Image(systemName: category.icon)
                            .foregroundStyle(.green)
                            .frame(width: 28)
                        Text(category.name)
                        Spacer()
                        if !category.children.isEmpty {
                            Text("\(category.children.count)个子分类")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    // MARK: - 搜索结果

    @ViewBuilder
    private var searchResults: some View {
        let filteredIngredients = ingredients.filter {
            searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText)
        }
        let filteredRecipes = recipes.filter {
            searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText)
        }

        List {
            if !filteredIngredients.isEmpty {
                Section("食材") {
                    ForEach(filteredIngredients) { ingredient in
                        NavigationLink {
                            IngredientDetailView(ingredient: ingredient)
                        } label: {
                            HStack {
                                Text(ingredient.emoji ?? "🥬")
                                Text(ingredient.name)
                            }
                        }
                    }
                }
            }

            if !filteredRecipes.isEmpty {
                Section("菜谱") {
                    ForEach(filteredRecipes) { recipe in
                        NavigationLink {
                            RecipeDetailView(recipe: recipe)
                        } label: {
                            Text(recipe.name)
                        }
                    }
                }
            }

            if filteredIngredients.isEmpty && filteredRecipes.isEmpty {
                ContentUnavailableView(
                    "未找到「\(searchText)」",
                    systemImage: "magnifyingglass",
                    description: Text("试试其他关键词，或在知识库中新建")
                )
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Load

    private func loadData() {
        ingredients = knowledgeService.getAllIngredients()
        recipes = knowledgeService.getAllRecipes()
        categories = knowledgeService.getAllCategories()
    }

    private func performSearch() {}
}

// MARK: - 分类详情

struct CategoryDetailView: View {
    @Environment(KnowledgeBaseService.self) private var knowledgeService
    let category: Category

    var body: some View {
        List {
            if !category.children.isEmpty {
                Section("子分类") {
                    ForEach(category.children) { child in
                        NavigationLink {
                            CategoryDetailView(category: child)
                        } label: {
                            HStack {
                                Image(systemName: child.icon)
                                    .foregroundStyle(.green)
                                Text(child.name)
                            }
                        }
                    }
                }
            }

            Section("食材") {
                let ingredients = knowledgeService.getAllIngredients().filter {
                    $0.category?.id == category.id || $0.category?.parent?.id == category.id
                }
                if ingredients.isEmpty {
                    Text("暂无食材")
                        .foregroundStyle(.secondary)
                }
                ForEach(ingredients) { ingredient in
                    NavigationLink {
                        IngredientDetailView(ingredient: ingredient)
                    } label: {
                        HStack {
                            Text(ingredient.emoji ?? "🥬")
                            Text(ingredient.name)
                        }
                    }
                }
            }

            Section("菜谱") {
                let recipes = knowledgeService.getAllRecipes().filter {
                    $0.category?.id == category.id
                }
                if recipes.isEmpty {
                    Text("暂无菜谱")
                        .foregroundStyle(.secondary)
                }
                ForEach(recipes) { recipe in
                    NavigationLink {
                        RecipeDetailView(recipe: recipe)
                    } label: {
                        Text(recipe.name)
                    }
                }
            }
        }
        .navigationTitle(category.name)
    }
}

import Foundation
import SwiftData
import Observation

/// 知识库服务 — 管理食材和菜谱的增删改查，支持动态扩展
@Observable
final class KnowledgeBaseService {
    private let modelContext: ModelContext
    var isLoaded = false

    /// 子服务（通过 KnowledgeBaseService 统一暴露给视图层）
    var recognitionService: RecognitionService
    var recipeMatchService: RecipeMatchService

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.recognitionService = RecognitionService()
        self.recipeMatchService = RecipeMatchService(modelContext: modelContext)
    }

    // MARK: - 食材操作

    func searchIngredients(query: String) -> [Ingredient] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
        let trimmed = query.trimmingCharacters(in: .whitespaces)

        let predicate = #Predicate<Ingredient> {
            $0.name.localizedStandardContains(trimmed) ||
            $0.aliases.contains(trimmed) ||
            $0.summary?.localizedStandardContains(trimmed) == true
        }
        let descriptor = FetchDescriptor(predicate: predicate)
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func getAllIngredients() -> [Ingredient] {
        let descriptor = FetchDescriptor<Ingredient>(sortBy: [SortDescriptor(\.name)])
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func getIngredient(by id: UUID) -> Ingredient? {
        let descriptor = FetchDescriptor<Ingredient>(predicate: #Predicate { $0.id == id })
        return try? modelContext.fetch(descriptor).first
    }

    @discardableResult
    func createIngredient(
        name: String,
        aliases: [String] = [],
        emoji: String? = nil,
        summary: String? = nil,
        category: Category? = nil,
        seasonMonths: [Int] = [],
        customFields: [String: AnyCodable] = [:]
    ) -> Ingredient {
        let ingredient = Ingredient(
            name: name,
            aliases: aliases,
            emoji: emoji,
            summary: summary,
            seasonMonths: seasonMonths,
            category: category,
            customFields: customFields,
            isBuiltIn: false
        )
        modelContext.insert(ingredient)
        return ingredient
    }

    func deleteIngredient(_ ingredient: Ingredient) {
        modelContext.delete(ingredient)
    }

    // MARK: - 菜谱操作

    func searchRecipes(query: String) -> [Recipe] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
        let trimmed = query.trimmingCharacters(in: .whitespaces)

        let predicate = #Predicate<Recipe> {
            $0.name.localizedStandardContains(trimmed) ||
            $0.summary?.localizedStandardContains(trimmed) == true
        }
        let descriptor = FetchDescriptor(predicate: predicate)
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func getAllRecipes(sortBy: SortOption = .updatedAt) -> [Recipe] {
        let sortDescriptors: [SortDescriptor<Recipe>]
        switch sortBy {
        case .name: sortDescriptors = [SortDescriptor(\.name)]
        case .createdAt: sortDescriptors = [SortDescriptor(\.createdAt, order: .reverse)]
        case .updatedAt: sortDescriptors = [SortDescriptor(\.updatedAt, order: .reverse)]
        case .difficulty: sortDescriptors = [SortDescriptor(\.difficulty)]
        case .cookingTime: sortDescriptors = [SortDescriptor(\.cookingTime)]
        }
        let descriptor = FetchDescriptor(sortBy: sortDescriptors)
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func getFavoriteRecipes() -> [Recipe] {
        let predicate = #Predicate<Recipe> { $0.isFavorite == true }
        let descriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func getSeasonalRecipes(month: Int) -> [Recipe] {
        // 当月食材推荐：找出当季食材，再匹配菜谱
        let ingredientPredicate = #Predicate<Ingredient> {
            $0.seasonMonths.contains(month)
        }
        let ingredientDescriptor = FetchDescriptor(predicate: ingredientPredicate)
        guard let seasonalIngredients = try? modelContext.fetch(ingredientDescriptor) else { return [] }

        let ingredientIDs = Set(seasonalIngredients.map(\.id))
        let recipeDescriptor = FetchDescriptor<Recipe>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        guard let allRecipes = try? modelContext.fetch(recipeDescriptor) else { return [] }

        return allRecipes.filter { recipe in
            recipe.ingredients.contains { ingredientIDs.contains($0.ingredient.id) }
        }
    }

    @discardableResult
    func createRecipe(
        name: String,
        summary: String? = nil,
        difficulty: Int = 1,
        cookingTime: Int = 15,
        servings: Int = 2,
        steps: [String] = [],
        tips: String? = nil,
        ingredients: [RecipeIngredient] = [],
        category: Category? = nil,
        tags: [Tag] = [],
        customFields: [String: AnyCodable] = [:]
    ) -> Recipe {
        let recipe = Recipe(
            name: name,
            summary: summary,
            difficulty: difficulty,
            cookingTime: cookingTime,
            servings: servings,
            steps: steps,
            tips: tips,
            ingredients: ingredients,
            category: category,
            tags: tags,
            customFields: customFields,
            isBuiltIn: false
        )
        modelContext.insert(recipe)
        return recipe
    }

    func toggleFavorite(recipe: Recipe) {
        recipe.isFavorite.toggle()
    }

    func deleteRecipe(_ recipe: Recipe) {
        modelContext.insert(recipe)
    }

    // MARK: - 分类操作

    func getAllCategories() -> [Category] {
        let predicate = #Predicate<Category> { $0.parent == nil }
        let descriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\.order)])
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func getAllTags() -> [Tag] {
        let descriptor = FetchDescriptor<Tag>(sortBy: [SortDescriptor(\.name)])
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    @discardableResult
    func createTag(name: String, colorHex: String? = nil) -> Tag {
        let tag = Tag(name: name, colorHex: colorHex, isCustom: true)
        modelContext.insert(tag)
        return tag
    }

    // MARK: - 扫描记录

    func saveScanRecord(
        imageData: Data? = nil,
        recognizedName: String,
        confidence: Float,
        source: ScanSource,
        ingredient: Ingredient?,
        recipes: [Recipe] = []
    ) -> ScanRecord {
        let record = ScanRecord(
            capturedImageData: imageData,
            recognizedName: recognizedName,
            confidence: confidence,
            source: source,
            matchedIngredient: ingredient,
            matchedRecipes: recipes
        )
        modelContext.insert(record)
        return record
    }

    func getScanHistory(limit: Int = 50) -> [ScanRecord] {
        let descriptor = FetchDescriptor<ScanRecord>(
            sortBy: [SortDescriptor(\.scannedAt, order: .reverse)]
        )
        let results = (try? modelContext.fetch(descriptor)) ?? []
        return Array(results.prefix(limit))
    }

    // MARK: - 当季推荐

    func getSeasonalIngredients(month: Int) -> [Ingredient] {
        let predicate = #Predicate<Ingredient> {
            $0.seasonMonths.contains(month)
        }
        let descriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\.name)])
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    // MARK: - 保存

    func save() {
        try? modelContext.save()
    }

    enum SortOption {
        case name, createdAt, updatedAt, difficulty, cookingTime
    }
}

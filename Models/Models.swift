import Foundation
import SwiftData
import UIKit

// MARK: - 动态字段协议
/// 实现此协议的类型支持用户自定义扩展字段，实现「内容可伸缩」
protocol DynamicFieldable {
    var customFields: [String: AnyCodable] { get set }
}

// MARK: - AnyCodable: 可存 JSON 的 Codable 包装
/// 用于 SwiftData 的 @Attribute(.transformable) 存储任意 JSON 数据
struct AnyCodable: Codable, Hashable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let v as String: try container.encode(v)
        case let v as Int: try container.encode(v)
        case let v as Double: try container.encode(v)
        case let v as Bool: try container.encode(v)
        case let v as [String: AnyCodable]: try container.encode(v)
        case let v as [AnyCodable]: try container.encode(v)
        default: try container.encodeNil()
        }
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let v = try? container.decode(String.self) { value = v }
        else if let v = try? container.decode(Int.self) { value = v }
        else if let v = try? container.decode(Double.self) { value = v }
        else if let v = try? container.decode(Bool.self) { value = v }
        else if let v = try? container.decode([String: AnyCodable].self) { value = v }
        else if let v = try? container.decode([AnyCodable].self) { value = v }
        else { value = "" }
    }

    static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        String(describing: lhs.value) == String(describing: rhs.value)
    }
    func hash(into hasher: inout Hasher) { hasher.combine(String(describing: value)) }
}

extension [String: AnyCodable] {
    /// 安全读取动态字段
    func get<T>(_ key: String, as type: T.Type = T.self) -> T? {
        self[key]?.value as? T
    }
}

// MARK: - 食材 Ingredient

@Model
final class Ingredient: DynamicFieldable {
    @Attribute(.unique) var id: UUID
    var name: String              // 食材名称
    var aliases: [String]         // 别名（如"土豆/马铃薯/洋芋"）
    var emoji: String?            // Emoji 图标
    var summary: String?          // 简短介绍
    var imageData: Data?          // 参考图片
    var seasonMonths: [Int]       // 当季月份 [1...12]
    var storageMethod: String?    // 存储方式
    var shelfLife: String?        // 保质期
    var nutritionJSON: String?    // 营养信息 JSON 字符串

    /// 关联
    @Relationship(deleteRule: .nullify) var category: Category?
    @Relationship(deleteRule: .nullify) var tags: [Tag]

    /// ⭐️ 动态扩展：用户可自加字段（如"产地", "挑选技巧"）
    var customFields: [String: AnyCodable]

    /// meta
    var isBuiltIn: Bool
    var createdAt: Date
    var updatedAt: Date

    /// 从食材查能做哪些菜 — 通过 RecipeIngredient 反向关联
    @Relationship(inverse: \RecipeIngredient.ingredient) var recipeIngredients: [RecipeIngredient]

    init(
        id: UUID = UUID(),
        name: String,
        aliases: [String] = [],
        emoji: String? = nil,
        summary: String? = nil,
        imageData: Data? = nil,
        seasonMonths: [Int] = [],
        storageMethod: String? = nil,
        shelfLife: String? = nil,
        nutritionJSON: String? = nil,
        category: Category? = nil,
        tags: [Tag] = [],
        customFields: [String: AnyCodable] = [:],
        isBuiltIn: Bool = false
    ) {
        self.id = id
        self.name = name
        self.aliases = aliases
        self.emoji = emoji
        self.summary = summary
        self.imageData = imageData
        self.seasonMonths = seasonMonths
        self.storageMethod = storageMethod
        self.shelfLife = shelfLife
        self.nutritionJSON = nutritionJSON
        self.category = category
        self.tags = tags
        self.customFields = customFields
        self.isBuiltIn = isBuiltIn
        self.createdAt = Date()
        self.updatedAt = Date()
        self.recipeIngredients = []
    }
}

// MARK: - 菜谱 Recipe

@Model
final class Recipe: DynamicFieldable {
    @Attribute(.unique) var id: UUID
    var name: String              // 菜名
    var summary: String?          // 简介
    var difficulty: Int           // 难度 1~5
    var cookingTime: Int          // 烹饪时间（分钟）
    var servings: Int             // 份量（几人份）
    var imageData: Data?          // 成品图
    var steps: [String]           // 步骤
    var tips: String?             // 小贴士
    var nutritionJSON: String?    // 营养信息 JSON

    /// 关联
    @Relationship(deleteRule: .cascade) var ingredients: [RecipeIngredient]
    @Relationship(deleteRule: .nullify) var category: Category?
    @Relationship(deleteRule: .nullify) var tags: [Tag]

    /// ⭐️ 动态扩展
    var customFields: [String: AnyCodable]

    /// meta
    var isBuiltIn: Bool
    var isFavorite: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        summary: String? = nil,
        difficulty: Int = 1,
        cookingTime: Int = 15,
        servings: Int = 2,
        imageData: Data? = nil,
        steps: [String] = [],
        tips: String? = nil,
        nutritionJSON: String? = nil,
        ingredients: [RecipeIngredient] = [],
        category: Category? = nil,
        tags: [Tag] = [],
        customFields: [String: AnyCodable] = [:],
        isBuiltIn: Bool = false,
        isFavorite: Bool = false
    ) {
        self.id = id
        self.name = name
        self.summary = summary
        self.difficulty = difficulty
        self.cookingTime = cookingTime
        self.servings = servings
        self.imageData = imageData
        self.steps = steps
        self.tips = tips
        self.nutritionJSON = nutritionJSON
        self.ingredients = ingredients
        self.category = category
        self.tags = tags
        self.customFields = customFields
        self.isBuiltIn = isBuiltIn
        self.isFavorite = isFavorite
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var formattedCookingTime: String {
        if cookingTime < 60 { return "\(cookingTime)分钟" }
        let h = cookingTime / 60
        let m = cookingTime % 60
        return m > 0 ? "\(h)小时\(m)分钟" : "\(h)小时"
    }

    var difficultyLabel: String {
        switch difficulty {
        case 1: "⭐ 新手"
        case 2: "⭐⭐ 简单"
        case 3: "⭐⭐⭐ 中等"
        case 4: "⭐⭐⭐⭐ 较难"
        case 5: "⭐⭐⭐⭐⭐ 大厨"
        default: "未知"
        }
    }
}

// MARK: - 菜谱-食材关联

@Model
final class RecipeIngredient {
    @Attribute(.unique) var id: UUID
    var quantity: String          // "300g", "2根", "适量"
    var isOptional: Bool          // 是否可选（可替换/可不加）

    @Relationship var ingredient: Ingredient
    @Relationship var recipe: Recipe?

    init(id: UUID = UUID(), ingredient: Ingredient, quantity: String, isOptional: Bool = false) {
        self.id = id
        self.ingredient = ingredient
        self.quantity = quantity
        self.isOptional = isOptional
    }
}

// MARK: - 分类 Category（支持无限层级）

@Model
final class Category {
    @Attribute(.unique) var id: UUID
    var name: String
    var icon: String              // SF Symbol 名称
    var order: Int                // 排序
    var isCustom: Bool            // 是否用户自定义

    @Relationship(deleteRule: .nullify) var parent: Category?
    @Relationship(deleteRule: .cascade) var children: [Category]

    init(id: UUID = UUID(), name: String, icon: String = "folder", order: Int = 0, isCustom: Bool = false, parent: Category? = nil) {
        self.id = id
        self.name = name
        self.icon = icon
        self.order = order
        self.isCustom = isCustom
        self.parent = parent
        self.children = []
    }
}

// MARK: - 标签 Tag

@Model
final class Tag {
    @Attribute(.unique) var id: UUID
    var name: String
    var colorHex: String?         // 标签颜色
    var isCustom: Bool

    init(id: UUID = UUID(), name: String, colorHex: String? = nil, isCustom: Bool = false) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.isCustom = isCustom
    }
}

// MARK: - 扫描记录

@Model
final class ScanRecord {
    @Attribute(.unique) var id: UUID
    var capturedImageData: Data?  // 扫描时的图片
    var recognizedName: String    // 识别出的食材名
    var confidence: Float         // 置信度
    var source: ScanSource
    var scannedAt: Date
    var isFavorite: Bool

    @Relationship var matchedIngredient: Ingredient?
    @Relationship var matchedRecipes: [Recipe]

    init(
        id: UUID = UUID(),
        capturedImageData: Data? = nil,
        recognizedName: String,
        confidence: Float = 0,
        source: ScanSource = .camera,
        matchedIngredient: Ingredient? = nil,
        matchedRecipes: [Recipe] = []
    ) {
        self.id = id
        self.capturedImageData = capturedImageData
        self.recognizedName = recognizedName
        self.confidence = confidence
        self.source = source
        self.matchedIngredient = matchedIngredient
        self.matchedRecipes = matchedRecipes
        self.scannedAt = Date()
        self.isFavorite = false
    }
}

enum ScanSource: String, Codable, CaseIterable {
    case camera = "相机"
    case photoLibrary = "相册"
    case manual = "手动输入"
}

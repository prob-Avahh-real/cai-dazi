import SwiftUI

struct IngredientDetailView: View {
    @Environment(KnowledgeBaseService.self) private var knowledgeService
    let ingredient: Ingredient
    @State private var matchedRecipes: [Recipe] = []

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 头部
                headerSection

                // 基本信息
                infoSection

                // 营养信息
                if let nutritionJSON = ingredient.nutritionJSON {
                    nutritionSection(json: nutritionJSON)
                }

                // 当季月份
                seasonSection

                // 关联菜谱
                if !matchedRecipes.isEmpty {
                    relatedRecipesSection
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(ingredient.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    ScanResultView(ingredient: ingredient, matchedRecipes: matchedRecipes)
                } label: {
                    Image(systemName: "fork.knife")
                }
            }
        }
        .onAppear {
            matchedRecipes = knowledgeService.recipeMatchService.matchRecipes(
                having: [ingredient],
                matchMode: .partial
            )
        }
    }

    // MARK: - 头部

    private var headerSection: some View {
        VStack(spacing: 12) {
            Text(ingredient.emoji ?? "🥬")
                .font(.system(size: 80))
            Text(ingredient.name)
                .font(.largeTitle.bold())

            if !ingredient.aliases.isEmpty {
                HStack(spacing: 4) {
                    Text("别名：")
                        .foregroundStyle(.secondary)
                    ForEach(ingredient.aliases, id: \.self) { alias in
                        Text(alias)
                            .font(.subheadline)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(.green.opacity(0.1))
                            )
                    }
                }
                .font(.subheadline)
            }

            if let summary = ingredient.summary {
                Text(summary)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.background)
                .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
        )
    }

    // MARK: - 信息

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("食材信息", systemImage: "info.circle.fill")
                .font(.headline)

            if let category = ingredient.category {
                infoRow(icon: "folder", label: "分类", value: category.name)
            }

            infoRow(icon: "thermometer", label: "存储", value: ingredient.storageMethod ?? "常温")

            if let shelfLife = ingredient.shelfLife {
                infoRow(icon: "clock.arrow.circlepath", label: "保质期", value: shelfLife)
            }

            if !ingredient.tags.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "tag")
                        .foregroundStyle(.secondary)
                        .frame(width: 24)
                    Text("标签")
                        .foregroundStyle(.secondary)
                    ForEach(ingredient.tags) { tag in
                        Text(tag.name)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(.green.opacity(0.1))
                            )
                    }
                }
            }

            // 动态字段
            ForEach(Array(ingredient.customFields.keys.sorted()), id: \.self) { key in
                if let value = ingredient.customFields.get(key, as: String.self) {
                    infoRow(icon: "ellipsis.circle", label: key, value: value)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.background)
                .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
        )
    }

    // MARK: - 营养信息

    private func nutritionSection(json: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("营养信息 (每100g)", systemImage: "chart.bar.fill")
                .font(.headline)
                .foregroundStyle(.orange)

            if let data = json.data(using: .utf8),
               let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {

                // 提取标准字段的值（去除单位）
                let calories = extractNumericValue(dict["calories"])
                let protein = extractNumericValue(dict["protein"])
                let fat = extractNumericValue(dict["fat"])
                let carbs = extractNumericValue(dict["carbohydrates"])
                let fiber = extractNumericValue(dict["fiber"])

                // 视觉条
                let maxValue = max(calories, protein * 4, fat * 9, carbs * 4, fiber * 4, 1)
                let maxBar: Double = 100

                nutritionBar(
                    icon: "flame.fill",
                    color: .red,
                    label: "热量",
                    value: dict["calories"],
                    barWidth: calories / maxValue * maxBar
                )
                nutritionBar(
                    icon: "figure.strengthtraining.traditional",
                    color: .blue,
                    label: "蛋白质",
                    value: dict["protein"],
                    barWidth: protein * 4 / maxValue * maxBar
                )
                nutritionBar(
                    icon: "drop.fill",
                    color: .yellow,
                    label: "脂肪",
                    value: dict["fat"],
                    barWidth: fat * 9 / maxValue * maxBar
                )
                nutritionBar(
                    icon: "circle.hexagongrid.fill",
                    color: .green,
                    label: "碳水",
                    value: dict["carbohydrates"],
                    barWidth: carbs * 4 / maxValue * maxBar
                )
                nutritionBar(
                    icon: "leaf.fill",
                    color: .teal,
                    label: "纤维",
                    value: dict["fiber"],
                    barWidth: fiber * 4 / maxValue * maxBar
                )

                // 额外字段（如果有）
                ForEach(Array(dict.keys.sorted().filter {
                    !["calories", "protein", "fat", "carbohydrates", "fiber"].contains($0)
                }), id: \.self) { key in
                    if let value = dict[key] {
                        infoRow(icon: "circle.fill", label: key, value: "\(value)")
                    }
                }
            } else {
                Text(json)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.background)
                .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
        )
    }

    private func nutritionBar(icon: String, color: Color, label: String, value: Any?, barWidth: Double) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .frame(width: 20)

                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(width: 48, alignment: .leading)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(color.opacity(0.12))
                            .frame(height: 10)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(color.gradient)
                            .frame(width: min(max(barWidth, 4), geo.size.width), height: 10)
                    }
                }
                .frame(height: 10)

                Text("\(value ?? "-")")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)
                    .frame(width: 72, alignment: .trailing)
            }
        }
    }

    /// 从如 "18 kcal" 的字符串中提取数字部分
    private func extractNumericValue(_ value: Any?) -> Double {
        guard let str = value as? String else { return 0 }
        let numericPart = str.components(separatedBy: CharacterSet.letters.union(.whitespaces)).joined()
        return Double(numericPart) ?? 0
    }

    // MARK: - 当季

    private var seasonSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("当季月份", systemImage: "leaf.fill")
                .font(.headline)
                .foregroundStyle(.green)

            if ingredient.seasonMonths.isEmpty {
                Text("全年皆可")
                    .foregroundStyle(.secondary)
            } else {
                HStack(spacing: 6) {
                    ForEach(1...12, id: \.self) { month in
                        Text("\(month)月")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(
                                        ingredient.seasonMonths.contains(month)
                                        ? Color.green : Color.secondary.opacity(0.1)
                                    )
                            )
                            .foregroundStyle(
                                ingredient.seasonMonths.contains(month)
                                ? .white : .secondary
                            )
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.background)
                .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
        )
    }

    // MARK: - 关联菜谱

    private var relatedRecipesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("相关菜谱", systemImage: "fork.knife")
                    .font(.headline)
                    .foregroundStyle(.orange)
                Spacer()
                Text("\(matchedRecipes.count) 道")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            }

            ForEach(matchedRecipes.prefix(5)) { recipe in
                NavigationLink {
                    RecipeDetailView(recipe: recipe)
                } label: {
                    RecipeRow(recipe: recipe)
                }
                .buttonStyle(.plain)
            }

            if matchedRecipes.count > 5 {
                NavigationLink {
                    ScanResultView(ingredient: ingredient, matchedRecipes: matchedRecipes)
                } label: {
                    Text("查看全部 \(matchedRecipes.count) 道菜谱")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.background)
                .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
        )
    }

    // MARK: - Helpers

    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 48, alignment: .leading)
            Text(value)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.subheadline)
    }
}

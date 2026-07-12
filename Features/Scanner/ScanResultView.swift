import SwiftUI

struct ScanResultView: View {
    @Environment(KnowledgeBaseService.self) private var knowledgeService
    let ingredient: Ingredient
    let matchedRecipes: [Recipe]

    @State private var recipes: [Recipe] = []
    @State private var matchMode: RecipeMatchService.MatchMode = .partial

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 食材信息头
                ingredientHeader

                // 食材百科信息
                ingredientInfoSection

                Divider()

                // 匹配菜谱
                matchHeader
                recipeList
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("识别结果")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadRecipes()
        }
    }

    // MARK: - 食材头部

    private var ingredientHeader: some View {
        VStack(spacing: 12) {
            Text(ingredient.emoji ?? "🥬")
                .font(.system(size: 72))
            Text(ingredient.name)
                .font(.largeTitle.bold())
            if let summary = ingredient.summary {
                Text(summary)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
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

    // MARK: - 百科信息

    private var ingredientInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("食材百科", systemImage: "book.fill")
                .font(.headline)

            infoRow(icon: "calendar", label: "当季", value: seasonText)
            infoRow(icon: "thermometer", label: "存储", value: ingredient.storageMethod ?? "常温储存")
            infoRow(icon: "clock.arrow.circlepath", label: "保质期", value: ingredient.shelfLife ?? "—")

            // 动态字段
            ForEach(Array(ingredient.customFields.keys.sorted()), id: \.self) { key in
                if let value = ingredient.customFields.get(key, as: String.self) {
                    infoRow(icon: "ellipsis.circle", label: key, value: value)
                }
            }

            if let category = ingredient.category {
                infoRow(icon: "folder", label: "分类", value: category.name)
            }

            if !ingredient.tags.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "tag")
                        .foregroundStyle(.secondary)
                        .frame(width: 24)
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
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.background)
                .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
        )
    }

    // MARK: - 匹配设置

    private var matchHeader: some View {
        VStack(spacing: 12) {
            HStack {
                Label("能做的菜", systemImage: "fork.knife")
                    .font(.headline)
                Spacer()
                Text("\(recipes.count) 道")
                    .foregroundStyle(.secondary)
            }

            Picker("匹配模式", selection: $matchMode) {
                Text("部分食材").tag(RecipeMatchService.MatchMode.partial)
                Text("全部匹配").tag(RecipeMatchService.MatchMode.exact)
            }
            .pickerStyle(.segmented)
            .onChange(of: matchMode) { _, _ in loadRecipes() }
        }
    }

    // MARK: - 菜谱列表

    private var recipeList: some View {
        LazyVStack(spacing: 12) {
            if recipes.isEmpty {
                ContentUnavailableView(
                    "没有找到匹配的菜谱",
                    systemImage: "fork.knife",
                    description: Text("试试切换匹配模式，或新建菜谱")
                )
            }

            ForEach(recipes) { recipe in
                NavigationLink {
                    RecipeDetailView(recipe: recipe)
                } label: {
                    RecipeRow(recipe: recipe)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Helpers

    private var seasonText: String {
        if ingredient.seasonMonths.isEmpty { return "全年" }
        let months = ingredient.seasonMonths.sorted().map { "\($0)月" }
        return months.joined(separator: "、")
    }

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

    private func loadRecipes() {
        let matchService = knowledgeService.recipeMatchService
        recipes = matchService.matchRecipes(
            having: [ingredient],
            matchMode: matchMode
        )
    }
}

// MARK: - 菜谱行

struct RecipeRow: View {
    let recipe: Recipe

    var body: some View {
        HStack(spacing: 16) {
            // 左侧图标
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.orange.opacity(0.1))
                    .frame(width: 60, height: 60)
                Text(recipe.ingredients.first?.ingredient.emoji ?? "🍳")
                    .font(.title2)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(recipe.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                HStack(spacing: 8) {
                    Label(recipe.formattedCookingTime, systemImage: "clock")
                    Label(recipe.difficultyLabel, systemImage: "flame")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.background)
                .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
        )
    }
}

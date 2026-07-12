import SwiftUI

struct RecipeDetailView: View {
    @Environment(KnowledgeBaseService.self) private var knowledgeService
    let recipe: Recipe

    @State private var showCreateCopy = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 头部
                headerSection

                // 基本信息
                infoSection

                // 用料
                ingredientsSection

                // 步骤
                stepsSection

                // 小贴士
                if let tips = recipe.tips, !tips.isEmpty {
                    tipsSection(tips)
                }

                // 动态字段
                dynamicFieldsSection
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(recipe.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 8) {
                    Button { knowledgeService.toggleFavorite(recipe: recipe) } label: {
                        Image(systemName: recipe.isFavorite ? "heart.fill" : "heart")
                            .foregroundStyle(.red)
                    }

                    Button { showCreateCopy = true } label: {
                        Image(systemName: "doc.badge.plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showCreateCopy) {
            RecipeCreateView(template: recipe)
        }
    }

    // MARK: - 头部

    private var headerSection: some View {
        VStack(spacing: 12) {
            if let imageData = recipe.imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.orange.opacity(0.1))
                        .frame(height: 160)
                    VStack(spacing: 8) {
                        Text("🍳")
                            .font(.system(size: 48))
                        Text(recipe.name)
                            .font(.title.bold())
                    }
                }
            }

            if let summary = recipe.summary {
                Text(summary)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - 基本信息

    private var infoSection: some View {
        HStack(spacing: 0) {
            infoItem(icon: "clock", value: recipe.formattedCookingTime, label: "时间")
            Divider()
                .frame(height: 40)
            infoItem(icon: "flame", value: String(repeating: "🔥", count: recipe.difficulty), label: recipe.difficultyLabel)
            Divider()
                .frame(height: 40)
            infoItem(icon: "person.2", value: "\(recipe.servings)人份", label: "份量")
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.background)
                .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
        )
    }

    private func infoItem(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.orange)
            Text(value)
                .font(.caption.weight(.medium))
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 用料

    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("用料", systemImage: "cart")
                .font(.headline)

            ForEach(recipe.ingredients) { ri in
                HStack {
                    Text(ri.ingredient.emoji ?? "🥬")
                    Text(ri.ingredient.name)
                        .font(.subheadline)
                    if ri.isOptional {
                        Text("可选")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(.secondary.opacity(0.15))
                            )
                    }
                    Spacer()
                    Text(ri.quantity)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.orange)
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.background)
                .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
        )
    }

    // MARK: - 步骤

    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("步骤", systemImage: "list.number")
                .font(.headline)

            ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(index + 1)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(.orange))

                    Text(step)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
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

    // MARK: - 小贴士

    private func tipsSection(_ tips: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lightbulb.fill")
                .foregroundStyle(.yellow)
            Text(tips)
                .font(.subheadline)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.yellow.opacity(0.08))
        )
    }

    // MARK: - 动态字段

    private var dynamicFieldsSection: some View {
        ForEach(Array(recipe.customFields.keys.sorted()), id: \.self) { key in
            if let value = recipe.customFields.get(key, as: String.self) {
                HStack {
                    Text(key)
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                    Spacer()
                    Text(value)
                        .font(.subheadline)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.background)
                )
            }
        }
    }
}

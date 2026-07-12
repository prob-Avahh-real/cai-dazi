import SwiftUI
import SwiftData

struct RecipeCreateView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(KnowledgeBaseService.self) private var knowledgeService

    var template: Recipe?

    @State private var name = ""
    @State private var summary = ""
    @State private var difficulty = 2
    @State private var cookingTime = 20
    @State private var servings = 2
    @State private var steps: [String] = [""]
    @State private var tips = ""
    @State private var selectedIngredients: [IngredientSelection] = []

    // 动态字段
    @State private var dynamicKeys: [String] = []
    @State private var dynamicValues: [String] = []

    @State private var showAddIngredient = false
    @State private var ingredientSearchText = ""
    @State private var ingredientSearchResults: [Ingredient] = []

    var body: some View {
        NavigationStack {
            Form {
                // 基本信息
                basicInfoSection

                // 用料
                ingredientsSection

                // 步骤
                stepsSection

                // 小贴士
                tipsSection

                // 动态字段
                dynamicFieldsSection
            }
            .navigationTitle(template != nil ? "以此菜谱创建" : "新建菜谱")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { saveRecipe() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { loadTemplate() }
            .sheet(isPresented: $showAddIngredient) {
                ingredientPickerSheet
            }
        }
    }

    // MARK: - 基本信息

    private var basicInfoSection: some View {
        Section("基本信息") {
            TextField("菜名 *", text: $name)

            TextField("简短描述", text: $summary)

            HStack {
                Text("难度")
                Spacer()
                Picker("", selection: $difficulty) {
                    Text("⭐ 新手").tag(1)
                    Text("⭐⭐ 简单").tag(2)
                    Text("⭐⭐⭐ 中等").tag(3)
                    Text("⭐⭐⭐⭐ 较难").tag(4)
                    Text("⭐⭐⭐⭐⭐ 大厨").tag(5)
                }
            }

            HStack {
                Text("烹饪时间")
                Spacer()
                TextField("分钟", value: $cookingTime, format: .number)
                    .keyboardType(.numberPad)
                    .frame(width: 60)
                    .multilineTextAlignment(.trailing)
                Text("分钟")
                    .foregroundStyle(.secondary)
            }

            Stepper("\(servings) 人份", value: $servings, in: 1...20)
        }
    }

    // MARK: - 用料

    private var ingredientsSection: some View {
        Section("用料") {
            ForEach(selectedIngredients.indices, id: \.self) { index in
                HStack {
                    Text(selectedIngredients[index].ingredient.emoji ?? "🥬")
                    Text(selectedIngredients[index].ingredient.name)
                    Spacer()
                    TextField("用量", text: $selectedIngredients[index].quantity)
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                }
            }
            .onDelete { selectedIngredients.remove(atOffsets: $0) }

            Button {
                showAddIngredient = true
            } label: {
                Label("添加食材", systemImage: "plus.circle")
            }
        }
    }

    // MARK: - 步骤

    private var stepsSection: some View {
        Section("步骤") {
            ForEach(steps.indices, id: \.self) { index in
                HStack(alignment: .top) {
                    Text("\(index + 1)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(.orange))

                    TextField("步骤 \(index + 1)", text: $steps[index], axis: .vertical)
                        .lineLimit(2...6)
                }
            }
            .onDelete { steps.remove(atOffsets: $0) }

            Button {
                steps.append("")
            } label: {
                Label("添加步骤", systemImage: "plus.circle")
            }
        }
    }

    // MARK: - 小贴士

    private var tipsSection: some View {
        Section("小贴士") {
            TextField("烹饪小技巧...", text: $tips, axis: .vertical)
                .lineLimit(2...4)
        }
    }

    // MARK: - 动态字段

    private var dynamicFieldsSection: some View {
        Section("自定义字段") {
            ForEach(dynamicKeys.indices, id: \.self) { index in
                HStack {
                    TextField("字段名", text: $dynamicKeys[index])
                        .frame(width: 80)
                    TextField("值", text: $dynamicValues[index])
                }
            }
            .onDelete { indices in
                dynamicKeys.remove(atOffsets: indices)
                dynamicValues.remove(atOffsets: indices)
            }

            Button {
                dynamicKeys.append("")
                dynamicValues.append("")
            } label: {
                Label("添加自定义字段", systemImage: "plus.circle")
            }
        }
    }

    // MARK: - 食材选择器

    private var ingredientPickerSheet: some View {
        NavigationStack {
            VStack {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("搜索食材", text: $ingredientSearchText)
                        .autocorrectionDisabled()
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.background)
                        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
                )
                .padding()

                List {
                    ForEach(ingredientSearchResults) { ingredient in
                        Button {
                            selectedIngredients.append(
                                IngredientSelection(ingredient: ingredient, quantity: "")
                            )
                            showAddIngredient = false
                        } label: {
                            HStack {
                                Text(ingredient.emoji ?? "🥬")
                                    .font(.title2)
                                Text(ingredient.name)
                                Spacer()
                                Image(systemName: "plus.circle")
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("选择食材")
            .onChange(of: ingredientSearchText) { _, new in
                ingredientSearchResults = knowledgeService.searchIngredients(query: new)
            }
        }
    }

    // MARK: - 保存

    private func saveRecipe() {
        let recipeIngredients = selectedIngredients.map { selection in
            RecipeIngredient(
                ingredient: selection.ingredient,
                quantity: selection.quantity
            )
        }

        let customFields = Dictionary(
            zip(dynamicKeys, dynamicValues)
                .filter { !$0.0.trimmingCharacters(in: .whitespaces).isEmpty }
                .map { ($0.0, AnyCodable($0.1)) },
            uniquingKeysWith: { $1 }
        )

        let recipe = knowledgeService.createRecipe(
            name: name.trimmingCharacters(in: .whitespaces),
            summary: summary.isEmpty ? nil : summary,
            difficulty: difficulty,
            cookingTime: cookingTime,
            servings: servings,
            steps: steps.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty },
            tips: tips.isEmpty ? nil : tips,
            ingredients: recipeIngredients,
            customFields: customFields
        )

        knowledgeService.save()
        dismiss()
    }

    private func loadTemplate() {
        guard let template else { return }
        name = template.name
        summary = template.summary ?? ""
        difficulty = template.difficulty
        cookingTime = template.cookingTime
        servings = template.servings
        steps = template.steps.isEmpty ? [""] : template.steps
        tips = template.tips ?? ""
        selectedIngredients = template.ingredients.map {
            IngredientSelection(ingredient: $0.ingredient, quantity: $0.quantity)
        }
    }
}

// MARK: - Helper

struct IngredientSelection {
    let ingredient: Ingredient
    var quantity: String
}

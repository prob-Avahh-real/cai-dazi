import Foundation
import SwiftData

// MARK: - 示例数据和数据库初始化

/// 应用首次启动时填充内置数据
struct SeedData {

    /// 生成营养 JSON（每 100g）
    static func nutrition(calories: Double, protein: Double, fat: Double, carbs: Double, fiber: Double = 0) -> String {
        let dict: [String: Any] = [
            "calories": "\(calories) kcal",
            "protein": "\(protein) g",
            "fat": "\(fat) g",
            "carbohydrates": "\(carbs) g",
            "fiber": "\(fiber) g",
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }

    static func populateIfNeeded(in modelContext: ModelContext) {
        // 检查是否已初始化
        let descriptor = FetchDescriptor<Category>()
        guard (try? modelContext.fetch(descriptor))?.isEmpty == true else { return }

        // 创建分类
        let vegetables = Category(name: "蔬菜", icon: "leaf", order: 1)
        let meat = Category(name: "肉类", icon: "flame", order: 2)
        let seafood = Category(name: "海鲜", icon: "water.waves", order: 3)
        let spices = Category(name: "调料", icon: "drop", order: 4)
        let fruits = Category(name: "水果", icon: "applelogo", order: 5)
        let grains = Category(name: "五谷杂粮", icon: "crown", order: 6)
        let dairy = Category(name: "蛋奶豆制品", icon: "circle", order: 7)

        for cat in [vegetables, meat, seafood, spices, fruits, grains, dairy] {
            modelContext.insert(cat)
        }

        // 子分类
        let leafyGreen = Category(name: "叶菜类", icon: "leaf", order: 1, parent: vegetables)
        let rootVeg = Category(name: "根茎类", icon: "leaf", order: 2, parent: vegetables)
        let fruitVeg = Category(name: "瓜果类", icon: "leaf", order: 3, parent: vegetables)
        let pork = Category(name: "猪肉", icon: "flame", order: 1, parent: meat)
        let chicken = Category(name: "鸡肉", icon: "flame", order: 2, parent: meat)
        let beef = Category(name: "牛肉", icon: "flame", order: 3, parent: meat)

        for cat in [leafyGreen, rootVeg, fruitVeg, pork, chicken, beef] {
            modelContext.insert(cat)
        }

        // 创建食材 (name, emoji, aliases, summary, category, seasonMonths, storage, shelfLife, nutritionJSON)
        typealias IngredientSeed = (String, String, [String], String?, Category?, [Int], String?, String?, String)
        let ingredients: [IngredientSeed] = [
            ("番茄", "🍅", ["西红柿", "洋柿子"],
             "番茄富含番茄红素和维生素C，酸甜多汁。选熟透的红番茄更适合炒菜做汤。",
             fruitVeg, [6,7,8,9], "常温避光", "约一周",
             nutrition(calories: 18, protein: 0.9, fat: 0.2, carbs: 3.9, fiber: 1.2)),

            ("土豆", "🥔", ["马铃薯", "洋芋"],
             "土豆是全球第四大粮食作物，含丰富淀粉和钾。发芽变绿的土豆不可食用。",
             rootVeg, [1,2,3,9,10,11,12], "阴凉通风", "约一个月",
             nutrition(calories: 76, protein: 2.0, fat: 0.1, carbs: 17.5, fiber: 2.2)),

            ("鸡蛋", "🥚", ["鸡子"],
             "鸡蛋是优质蛋白来源，含全部必需氨基酸。一个鸡蛋约含6克蛋白质。",
             dairy, [], "冷藏", "约两周",
             nutrition(calories: 144, protein: 13.3, fat: 9.5, carbs: 1.5, fiber: 0)),

            ("鸡胸肉", "🍗", ["鸡胸"],
             "鸡胸肉是极低脂高蛋白的白肉，100g含约23g蛋白质。健身首选蛋白质来源。",
             chicken, [], "冷藏冷冻", "冷藏3天",
             nutrition(calories: 133, protein: 23.3, fat: 4.5, carbs: 0, fiber: 0)),

            ("洋葱", "🧅", ["洋葱", "葱头"],
             "洋葱含硫化物，有杀菌作用。紫皮洋葱更辛辣适合炒菜，黄皮洋葱更甜适合做汤。",
             rootVeg, [4,5,6,7,8,9], "阴凉通风", "约一个月",
             nutrition(calories: 40, protein: 1.1, fat: 0.1, carbs: 9.3, fiber: 1.7)),

            ("大蒜", "🧄", ["蒜头"],
             "大蒜含大蒜素，具有强烈杀菌作用。切碎放置10分钟再烹饪，大蒜素活性最高。",
             spices, [], "阴凉通风", "数月",
             nutrition(calories: 149, protein: 6.4, fat: 0.5, carbs: 33.1, fiber: 2.1)),

            ("生姜", "🫚", ["姜"],
             "生姜含姜辣素，去腥增香效果好。嫩姜适合腌制，老姜适合炖煮。",
             spices, [], "冷藏", "约两周",
             nutrition(calories: 80, protein: 1.8, fat: 0.8, carbs: 17.8, fiber: 2.0)),

            ("葱", "🌱", ["青葱", "小葱"],
             "葱含挥发油和蒜素，去腥提味。葱白适合爆香，葱绿适合装饰和凉拌。",
             leafyGreen, [4,5,6,7,8,9], "冷藏", "约一周",
             nutrition(calories: 34, protein: 1.8, fat: 0.4, carbs: 7.0, fiber: 1.8)),

            ("生抽", "🫗", ["酱油"],
             "生抽是黄豆发酵酿造而成，鲜味主要来自氨基酸。生抽提鲜，老抽上色。",
             spices, [], "阴凉", "长期",
             nutrition(calories: 53, protein: 7.8, fat: 0, carbs: 5.6, fiber: 0)),

            ("盐", "🧂", ["食盐"],
             "食盐主要成分为氯化钠。成人每日推荐摄入量不超过6克。",
             spices, [], "阴凉", "长期",
             nutrition(calories: 0, protein: 0, fat: 0, carbs: 0, fiber: 0)),

            ("食用油", "🫒", ["油", "植物油"],
             "常用烹饪油。不同烟点决定用途：低烟点油适合凉拌，高烟点油适合煎炸。",
             spices, [], "阴凉", "数月",
             nutrition(calories: 899, protein: 0, fat: 99.9, carbs: 0, fiber: 0)),

            ("大米", "🍚", ["米饭", "白米"],
             "大米是东亚主要主食。煮饭时米水比例1:1.2口感最佳。",
             grains, [], "阴凉密封", "约六个月",
             nutrition(calories: 116, protein: 2.6, fat: 0.3, carbs: 25.9, fiber: 0.3)),

            ("猪肉", "🥩", ["五花肉", "瘦肉"],
             "猪肉是中国人消费量最大的肉类。五花肉肥瘦相间适合红烧，里脊瘦肉适合快炒。",
             pork, [], "冷藏冷冻", "冷藏3天",
             nutrition(calories: 395, protein: 13.2, fat: 37.0, carbs: 2.4, fiber: 0)),

            ("牛肉", "🥩", [],
             "牛肉富含铁和蛋白质。牛腩适合炖煮，牛里脊适合快炒，牛排适合煎制。",
             beef, [], "冷藏冷冻", "冷藏3天",
             nutrition(calories: 125, protein: 19.9, fat: 4.2, carbs: 2.0, fiber: 0)),

            ("豆腐", "🫘", [],
             "豆腐是优质植物蛋白来源，含大豆异黄酮。嫩豆腐适合做汤，老豆腐适合煎炒。",
             dairy, [], "冷藏泡水", "约一周",
             nutrition(calories: 76, protein: 8.1, fat: 4.8, carbs: 1.9, fiber: 0.3)),

            ("胡萝卜", "🥕", ["红萝卜"],
             "胡萝卜含丰富β-胡萝卜素，体内可转化为维生素A。用油炒更有利于营养吸收。",
             rootVeg, [1,2,3,9,10,11,12], "冷藏", "约两周",
             nutrition(calories: 41, protein: 0.9, fat: 0.2, carbs: 9.6, fiber: 2.8)),

            ("西兰花", "🥦", ["青花菜", "花椰菜"],
             "西兰花是十字花科蔬菜，含萝卜硫素，抗氧化能力强。焯水后颜色更翠绿。",
             leafyGreen, [9,10,11,12,1,2,3,4], "冷藏", "约一周",
             nutrition(calories: 34, protein: 2.8, fat: 0.4, carbs: 6.6, fiber: 2.6)),

            ("白菜", "🥬", ["大白菜", "小白菜"],
             "白菜是冬季最常见的叶菜，价格实惠且耐储存。外层叶片营养更丰富。",
             leafyGreen, [10,11,12,1,2,3], "冷藏", "约两周",
             nutrition(calories: 13, protein: 1.5, fat: 0.2, carbs: 2.2, fiber: 1.0)),

            ("青椒", "🫑", ["甜椒", "灯笼椒"],
             "青椒维生素C含量极高，一个青椒即可满足成人每日所需。适合快炒保持脆嫩。",
             fruitVeg, [5,6,7,8,9,10], "冷藏", "约一周",
             nutrition(calories: 20, protein: 0.9, fat: 0.2, carbs: 4.6, fiber: 1.7)),

            ("茄子", "🍆", ["紫茄", "落苏"],
             "茄子吸油性强，炒前用盐腌制挤水可减少吸油量。紫色外皮含花青素。",
             fruitVeg, [6,7,8,9,10], "冷藏", "约一周",
             nutrition(calories: 25, protein: 1.0, fat: 0.2, carbs: 5.9, fiber: 3.0)),

            ("黄瓜", "🥒", ["青瓜", "胡瓜"],
             "黄瓜含水量超95%，热量极低。皮中含丰富营养，建议洗净后带皮食用。",
             fruitVeg, [5,6,7,8,9], "冷藏", "约一周",
             nutrition(calories: 16, protein: 0.7, fat: 0.1, carbs: 2.9, fiber: 0.5)),

            ("面条", "🍜", ["面", "挂面"],
             "面条是便捷主食。煮面时加少许盐和油可防粘连。过凉水让口感更筋道。",
             grains, [], "阴凉", "长期",
             nutrition(calories: 300, protein: 9.8, fat: 1.1, carbs: 60.5, fiber: 1.5)),

            ("虾", "🦐", ["虾仁", "海虾"],
             "虾肉蛋白含量高、脂肪极低，是优质蛋白来源。虾线是消化道，烹饪前应去除。",
             seafood, [3,4,5,6,7,8,9], "冷藏冷冻", "冷藏2天",
             nutrition(calories: 87, protein: 18.6, fat: 0.8, carbs: 2.8, fiber: 0)),

            ("香菇", "🍄", ["冬菇", "花菇"],
             "香菇含香菇多糖，有增强免疫力作用。干香菇的鲜味物质比鲜香菇更丰富。",
             vegetables, [3,4,5,6,7,8,9,10,11], "冷藏", "约一周",
             nutrition(calories: 34, protein: 2.7, fat: 0.4, carbs: 5.2, fiber: 3.3)),

            ("玉米", "🌽", ["甜玉米", "苞谷"],
             "玉米是粗粮中的营养佳品，富含膳食纤维和叶黄素。煮玉米保留外皮更香甜。",
             grains, [7,8,9,10], "冷藏", "约一周",
             nutrition(calories: 112, protein: 4.0, fat: 2.0, carbs: 22.8, fiber: 2.9)),
        ]

        var ingredientMap: [String: Ingredient] = [:]
        for (name, emoji, aliases, summary, category, season, storage, shelfLife, nutritionJSON) in ingredients {
            let ing = Ingredient(
                name: name,
                aliases: aliases,
                emoji: emoji,
                summary: summary,
                seasonMonths: season,
                storageMethod: storage,
                shelfLife: shelfLife,
                nutritionJSON: nutritionJSON,
                category: category,
                isBuiltIn: true
            )
            modelContext.insert(ing)
            ingredientMap[name] = ing
        }

        // 创建菜谱
        let recipeData: [(String, String?, Int, Int, Int, [String], String?, [(String, String, Bool)])] = [
            ("番茄炒蛋", "经典家常菜，酸甜可口，简单快捷", 1, 15, 2,
             ["番茄切块，鸡蛋打散加少许盐",
              "热锅凉油，倒入蛋液炒至凝固盛出",
              "锅中加油，放入番茄炒出汁水",
              "倒入鸡蛋翻炒均匀，加盐和糖调味即可"],
             "番茄选熟透的更多汁。加少许糖可以提鲜中和酸味。",
             [("番茄", "2个", false), ("鸡蛋", "3个", false), ("盐", "适量", false), ("葱", "少许", true)]),

            ("土豆烧牛肉", "软烂香浓，下饭利器", 3, 60, 3,
             ["牛肉切块焯水去血沫",
              "土豆胡萝卜切滚刀块",
              "锅中加油，炒香姜葱，放入牛肉翻炒",
              "加生抽、料酒、足量热水，小火炖40分钟",
              "放入土豆胡萝卜继续炖15分钟至软烂",
              "大火收汁，加盐调味"],
             "牛肉选牛腩或牛腱子更易炖烂。用高压锅可缩短一半时间。",
             [("牛肉", "500g", false), ("土豆", "2个", false), ("胡萝卜", "1根", false), ("生姜", "3片", false), ("葱", "2根", false), ("生抽", "2勺", false), ("盐", "适量", false), ("食用油", "适量", false)]),

            ("青椒肉丝", "快手家常菜，肉嫩椒香", 2, 15, 2,
             ["猪肉切丝，加生抽、淀粉腌制10分钟",
              "青椒切丝备用",
              "热锅下油，滑炒肉丝至变色盛出",
              "锅中加油，炒香青椒丝",
              "倒回肉丝翻炒，加盐和生抽调味"],
             "肉丝加少许水淀粉抓匀更嫩滑。",
             [("猪肉", "200g", false), ("青椒", "2个", false), ("生抽", "1勺", false), ("盐", "适量", false), ("食用油", "适量", false)]),

            ("葱油拌面", "简约不简单，一分钟搞定", 1, 10, 1,
             ["面条煮熟捞出过凉水",
              "碗中加入生抽、少许醋",
              "撒上葱花，淋上热油",
              "拌匀即可"],
             "油要烧到微微冒烟再淋，才能激发出葱香。",
             [("面条", "1份", false), ("葱", "3根", false), ("生抽", "1勺", false), ("食用油", "1勺", false)]),

            ("西兰花炒虾仁", "低脂高蛋白，清爽鲜美", 2, 15, 2,
             ["西兰花掰小朵焯水1分钟",
              "虾仁加料酒、白胡椒粉腌制",
              "锅中加油，炒香蒜末",
              "放入虾仁炒至变色",
              "加入西兰花翻炒，加盐调味"],
             "焯水时加几滴油，西兰花更翠绿。",
             [("西兰花", "1颗", false), ("虾", "200g", false), ("大蒜", "3瓣", false), ("盐", "适量", false), ("食用油", "适量", false)]),

            ("麻婆豆腐", "麻辣鲜香，下饭神器", 2, 20, 2,
             ["豆腐切块焯水去豆腥",
              "锅中加油，炒香肉末",
              "加入豆瓣酱炒出红油",
              "加适量水烧开，放入豆腐小火煮5分钟",
              "淋入水淀粉勾芡，撒上花椒粉和葱花"],
             "豆腐用嫩豆腐口感最好。勾芡分两次，汤汁更浓稠。",
             [("豆腐", "1块", false), ("猪肉", "100g", false), ("葱", "2根", false), ("大蒜", "3瓣", false), ("食用油", "适量", false), ("盐", "适量", true)]),

            ("蒜蓉西兰花", "清清爽爽，零失败", 1, 10, 2,
             ["西兰花掰小朵洗净",
              "焯水1分钟捞出",
              "锅中加油，炒香蒜末",
              "放入西兰花快速翻炒，加盐调味即可"],
             "不要炒太久，保持脆嫩口感。",
             [("西兰花", "1颗", false), ("大蒜", "4瓣", false), ("盐", "适量", false), ("食用油", "适量", false)]),

            ("可乐鸡翅", "甜香软糯，全家都爱", 2, 35, 3,
             ["鸡翅洗净划两刀，焯水去血沫",
              "锅中加油，将鸡翅煎至两面金黄",
              "倒入可乐没过鸡翅",
              "加生抽、姜片，中小火煮25分钟",
              "大火收汁至浓稠即可"],
             "收汁时要盯着锅，容易糊。用无糖可乐更健康。",
             [("鸡胸肉", "8个鸡翅", false), ("生姜", "3片", false), ("生抽", "1勺", false), ("食用油", "适量", false)]),
        ]

        for (name, summary, difficulty, time, servings, steps, tips, ings) in recipeData {
            let recipe = Recipe(
                name: name,
                summary: summary,
                difficulty: difficulty,
                cookingTime: time,
                servings: servings,
                steps: steps,
                tips: tips,
                isBuiltIn: true
            )
            for (ingName, qty, optional) in ings {
                if let ingredient = ingredientMap[ingName] {
                    let ri = RecipeIngredient(
                        ingredient: ingredient,
                        quantity: qty,
                        isOptional: optional
                    )
                    recipe.ingredients.append(ri)
                }
            }
            modelContext.insert(recipe)
        }

        try? modelContext.save()
    }
}

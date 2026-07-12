import SwiftUI
import SwiftData

@main
struct 菜搭子App: App {
    let modelContainer: ModelContainer

    init() {
        let schema = Schema([
            Ingredient.self,
            Recipe.self,
            RecipeIngredient.self,
            Category.self,
            Tag.self,
            ScanRecord.self,
        ])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )

        do {
            modelContainer = try ModelContainer(
                for: schema,
                configurations: configuration
            )
        } catch {
            fatalError("数据库初始化失败: \(error.localizedDescription)")
        }

        // 首次启动填充内置数据
        let context = modelContainer.mainContext
        SeedData.populateIfNeeded(in: context)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var knowledgeService: KnowledgeBaseService?
    @State private var selectedTab: Tab = .home

    enum Tab: String, CaseIterable {
        case home = "首页"
        case knowledge = "知识库"
        case collections = "收藏"
        case profile = "我的"

        var icon: String {
            switch self {
            case .home: "house"
            case .knowledge: "book"
            case .collections: "heart"
            case .profile: "person"
            }
        }
    }

    var body: some View {
        Group {
            if let ks = knowledgeService {
                TabView(selection: $selectedTab) {
                    HomeView()
                        .tabItem { Label(Tab.home.rawValue, systemImage: Tab.home.icon) }
                        .tag(Tab.home)

                    KnowledgeBaseView()
                        .tabItem { Label(Tab.knowledge.rawValue, systemImage: Tab.knowledge.icon) }
                        .tag(Tab.knowledge)

                    CollectionsView()
                        .tabItem { Label(Tab.collections.rawValue, systemImage: Tab.collections.icon) }
                        .tag(Tab.collections)

                    ProfileView()
                        .tabItem { Label(Tab.profile.rawValue, systemImage: Tab.profile.icon) }
                        .tag(Tab.profile)
                }
                .tint(.green)
                .environment(ks)
            } else {
                ProgressView("加载中...")
                    .task {
                        knowledgeService = KnowledgeBaseService(modelContext: modelContext)
                    }
            }
        }
    }
}

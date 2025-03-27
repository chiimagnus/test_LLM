import SwiftUI
import SwiftData

@main
struct test_LLMApp: App {
    // 创建SwiftData模型容器
    let modelContainer: ModelContainer
    
    init() {
        do {
            // 配置SwiftData模型容器
            let schema = Schema([
                ApiKeyConfig.self,
                PersistentChatMessage.self,
                ChatSession.self,
                ActivityRecord.self
            ])
            
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )
            
            modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("无法设置SwiftData模型容器: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }
}

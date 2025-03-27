import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                ChatView()
            }
            .tabItem {
                Label("聊天", systemImage: "message.fill")
            }
//            .tag(0)
//            
//            NavigationStack {
//                ActivityView()
//            }
//            .tabItem {
//                Label("活动记录", systemImage: "list.bullet.clipboard.fill")
//            }
//            .tag(1)
        }
    }
}

#Preview {
    ContentView()
}

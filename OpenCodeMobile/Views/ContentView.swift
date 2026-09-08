import SwiftUI

// MARK: - ContentView
// 主界面: 两个 Tab — 会话列表 和 设置

struct ContentView: View {
    @Environment(ConnectionViewModel.self) private var connectionVM
    @Environment(AppLifecycleManager.self) private var lifecycleManager

    @State private var selectedTab = 0
    @State private var showConnectionAlert = false

    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: 会话列表
            NavigationStack {
                SessionListView()
            }
            .tabItem {
                Label("会话", systemImage: "bubble.left.and.bubble.right")
            }
            .tag(0)

            // Tab 2: 设置
            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("设置", systemImage: "gear")
            }
            .tag(1)
        }
        .onChange(of: connectionVM.connectionState) { _, newValue in
            if newValue == .connected {
                // 连接成功, 切换到会话列表
                selectedTab = 0
            }
        }
        .alert("未配置", isPresented: $showConnectionAlert) {
            Button("去设置") {
                selectedTab = 1
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("请先在设置中配置服务器地址和密码")
        }
        // 环境监听前台/后台
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            lifecycleManager.handleEnterBackground()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            lifecycleManager.handleEnterForeground()
        }
    }
}

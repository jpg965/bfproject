import SwiftUI
import SwiftData

// MARK: - OpenCodeMobileApp
// App 入口点

@main
struct OpenCodeMobileApp: App {
    @State private var connectionVM = ConnectionViewModel()
    @State private var lifecycleManager = AppLifecycleManager.shared
    @State private var dataStore = DataStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(connectionVM)
                .environment(connectionVM.apiClient)
                .environment(connectionVM.sseClient)
                .environment(lifecycleManager)
                .environment(dataStore)
                .onAppear {
                    // 自动连接 (如果已配置)
                    if connectionVM.isConfigured {
                        connectionVM.connect()
                    }
                    lifecycleManager.handleEnterForeground()
                }
                .onDisappear {
                    lifecycleManager.handleEnterBackground()
                }
        }
    }
}

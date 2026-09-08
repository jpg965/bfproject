import Foundation
import SwiftUI

// MARK: - ConnectionViewModel
// 管理服务器连接配置和状态

@Observable
final class ConnectionViewModel {
    var serverConfig: ServerConfig {
        didSet {
            saveConfig()
            apiClient.serverConfig = serverConfig
        }
    }
    var password: String {
        didSet {
            KeychainHelper.save(password: password)
            apiClient.password = password
        }
    }

    var connectionState: ConnectionState = .disconnected
    var serverVersion: String?
    var errorMessage: String?

    let apiClient: APIClient
    let sseClient: SSEClient

    private let configKey = "ServerConfig"

    init() {
        // 从 UserDefaults 加载配置
        let loadedConfig: ServerConfig
        if let data = UserDefaults.standard.data(forKey: "ServerConfig"),
           let config = try? JSONDecoder().decode(ServerConfig.self, from: data) {
            loadedConfig = config
        } else {
            loadedConfig = ServerConfig()
        }
        self.serverConfig = loadedConfig

        // 从 Keychain 加载密码
        let loadedPassword = KeychainHelper.load() ?? ""
        self.password = loadedPassword

        self.apiClient = APIClient(serverConfig: loadedConfig, password: loadedPassword.isEmpty ? nil : loadedPassword)
        self.sseClient = SSEClient()

        // 配置生命周期管理器
        AppLifecycleManager.shared.configure(
            apiClient: apiClient,
            sseClient: sseClient,
            serverConfig: loadedConfig,
            password: loadedPassword.isEmpty ? nil : loadedPassword
        )
    }

    // MARK: - 连接测试

    func testConnection() async {
        connectionState = .connecting
        errorMessage = nil

        do {
            let health = try await apiClient.checkHealth()
            connectionState = .connected
            serverVersion = health.version
        } catch let error as APIError {
            connectionState = .error
            errorMessage = error.errorDescription
        } catch {
            connectionState = .error
            errorMessage = error.localizedDescription
        }
    }

    /// 连接到服务器并启动 SSE
    func connect() {
        Task {
            await testConnection()
            if connectionState == .connected {
                sseClient.connect(config: serverConfig, password: password.isEmpty ? nil : password)
            }
        }
    }

    /// 断开连接
    func disconnect() {
        sseClient.disconnect()
        connectionState = .disconnected
    }

    // MARK: - 持久化

    private func saveConfig() {
        if let data = try? JSONEncoder().encode(serverConfig) {
            UserDefaults.standard.set(data, forKey: configKey)
        }
        // 更新生命周期管理器
        AppLifecycleManager.shared.configure(
            apiClient: apiClient,
            sseClient: sseClient,
            serverConfig: serverConfig,
            password: password.isEmpty ? nil : password
        )
    }

    var isConfigured: Bool {
        !serverConfig.hostname.isEmpty && !password.isEmpty
    }
}

// MARK: - ConnectionState

enum ConnectionState {
    case disconnected
    case connecting
    case connected
    case error

    var displayText: String {
        switch self {
        case .disconnected: return "未连接"
        case .connecting: return "连接中..."
        case .connected: return "已连接"
        case .error: return "连接错误"
        }
    }

    var color: Color {
        switch self {
        case .disconnected: return .secondary
        case .connecting: return .orange
        case .connected: return .green
        case .error: return .red
        }
    }
}

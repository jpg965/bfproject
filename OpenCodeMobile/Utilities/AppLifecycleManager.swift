import Foundation
import SwiftUI
import Combine

// MARK: - AppLifecycleManager
// 管理 App 前台/后台切换，控制 SSE 连接和后台轮询
//
// 策略:
// - 进入前台: 启动 SSE 连接
// - 进入后台: 断开 SSE, 启动定时轮询 (每 15s 拉取最新消息)
// - 回到前台: 断开轮询, 重连 SSE, 拉取增量消息

@Observable
final class AppLifecycleManager {
    static let shared = AppLifecycleManager()

    var isForeground = true
    var backgroundPollingTimer: Timer?

    // 后台轮询间隔 (秒)
    private let backgroundPollInterval: TimeInterval = 15.0
    // 后台轮询时只拉取最新 1 条消息检查是否有新内容
    private let backgroundPollLimit = 1

    private var apiClient: APIClient?
    private var sseClient: SSEClient?
    private var serverConfig: ServerConfig?
    private var password: String?
    private var currentSessionID: String?

    // 后台检测到新消息时回调
    var onNewMessagesDetected: (() -> Void)?

    // 用于跟踪上次已知的消息时间戳
    private var lastKnownMessageTime: Double = 0

    private init() {}

    func configure(
        apiClient: APIClient,
        sseClient: SSEClient,
        serverConfig: ServerConfig,
        password: String?
    ) {
        self.apiClient = apiClient
        self.sseClient = sseClient
        self.serverConfig = serverConfig
        self.password = password
    }

    /// 设置当前活跃的会话 ID (用于后台轮询)
    func setActiveSession(id: String?) {
        self.currentSessionID = id
    }

    // MARK: - 生命周期事件

    func handleEnterForeground() {
        isForeground = true
        stopBackgroundPolling()

        // 重连 SSE
        if let config = serverConfig {
            sseClient?.resume(config: config, password: password)
        }

        // 拉取增量消息
        Task {
            await fetchIncrementalMessages()
        }
    }

    func handleEnterBackground() {
        isForeground = false
        // 断开 SSE (iOS 会在后台挂起 URLSession)
        sseClient?.pause()
        // 启动后台轮询
        startBackgroundPolling()
    }

    // MARK: - 后台轮询

    private func startBackgroundPolling() {
        stopBackgroundPolling()

        backgroundPollingTimer = Timer.scheduledTimer(
            withTimeInterval: backgroundPollInterval,
            repeats: true
        ) { [weak self] _ in
            Task { [weak self] in
                await self?.pollMessages()
            }
        }
    }

    private func stopBackgroundPolling() {
        backgroundPollingTimer?.invalidate()
        backgroundPollingTimer = nil
    }

    /// 后台轮询: 检查是否有新消息
    private func pollMessages() async {
        guard let apiClient = apiClient,
              let sessionID = currentSessionID else { return }

        do {
            let messages = try await apiClient.listMessages(sessionID: sessionID, limit: 1)
            guard let latest = messages.last else { return }

            let latestTime = latest.info.time?.created ?? 0
            if latestTime > lastKnownMessageTime && lastKnownMessageTime > 0 {
                // 有新消息
                await MainActor.run {
                    self.onNewMessagesDetected?()
                }
            }
            if latestTime > 0 {
                lastKnownMessageTime = latestTime
            }
        } catch {
            // 后台轮询失败静默处理, 下次再试
            print("后台轮询失败: \(error.localizedDescription)")
        }
    }

    /// 前台恢复时拉取增量消息
    private func fetchIncrementalMessages() async {
        guard let apiClient = apiClient,
              let sessionID = currentSessionID else { return }

        do {
            let messages = try await apiClient.listMessages(sessionID: sessionID)
            if let latest = messages.last {
                let latestTime = latest.info.time?.created ?? 0
                if latestTime > lastKnownMessageTime {
                    await MainActor.run {
                        self.onNewMessagesDetected?()
                    }
                    lastKnownMessageTime = latestTime
                }
            }
        } catch {
            print("增量拉取失败: \(error.localizedDescription)")
        }
    }

    /// 更新已知最新消息时间戳
    func updateLastKnownTime(_ time: Double) {
        if time > lastKnownMessageTime {
            lastKnownMessageTime = time
        }
    }
}

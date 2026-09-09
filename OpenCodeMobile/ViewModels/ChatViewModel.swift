import Foundation
import SwiftUI

// MARK: - ChatViewModel
// 管理单个会话的聊天交互: 消息拉取、发送、SSE 实时更新

@Observable
@MainActor
final class ChatViewModel {
    var sessionID: String
    var messages: [MessageResponse] = []
    var isLoading = false
    var isSending = false
    var errorMessage: String?
    var isStreaming = false  // AI 是否正在流式输出
    var streamingText = ""   // 流式输出中的临时文本

    // 用于增量更新: 流式 Part 累积
    private var streamingPartID: String?
    private var streamingMessageID: String?

    private let apiClient: APIClient
    private let dataStore: DataStore
    private var sseClient: SSEClient
    private let sessionTitle: String
    private let liveActivity = LiveActivityManager.shared

    init(sessionID: String, apiClient: APIClient, dataStore: DataStore, sseClient: SSEClient,
         sessionTitle: String = "AI 会话") {
        self.sessionID = sessionID
        self.sessionTitle = sessionTitle
        self.apiClient = apiClient
        self.dataStore = dataStore
        self.sseClient = sseClient

        // 设置活跃会话 (用于后台轮询)
        AppLifecycleManager.shared.setActiveSession(id: sessionID)

        // 先加载缓存
        loadCachedMessages()
    }

    // MARK: - 加载消息

    /// 从本地缓存加载消息
    func loadCachedMessages() {
        let cached = dataStore.fetchMessages(sessionID: sessionID)
        messages = cached.compactMap { c -> MessageResponse? in
            guard let rawJSON = c.rawJSON,
                  let response = try? JSONDecoder().decode(MessageResponse.self, from: rawJSON) else {
                // 如果没有原始 JSON, 构造一个简单的文本消息
                let part = MessagePart(id: c.id, type: .text, text: c.textContent, tool: nil, error: nil)
                let info = MessageInfo(
                    id: c.id, role: c.role, sessionID: sessionID,
                    time: MessageInfo.MessageTime(created: c.createdAt.timeIntervalSince1970 * 1000,
                                                  completed: c.createdAt.timeIntervalSince1970 * 1000),
                    cost: nil, tokens: nil
                )
                return MessageResponse(info: info, parts: [part])
            }
            return response
        }
    }

    /// 从服务器拉取完整消息列表
    func fetchMessages() async {
        isLoading = true
        errorMessage = nil

        do {
            let remoteMessages = try await apiClient.listMessages(sessionID: sessionID)
            messages = remoteMessages

            // 缓存
            dataStore.upsertMessages(remoteMessages, for: sessionID)

            // 更新已知最新时间
            if let latest = remoteMessages.last {
                AppLifecycleManager.shared.updateLastKnownTime(latest.info.time?.created ?? 0)
            }
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - 发送消息

    /// 发送消息 (异步方式: 通过 SSE 接收回复)
    func sendMessage(text: String) async {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        isSending = true
        isStreaming = true
        streamingText = ""
        errorMessage = nil

        // 先在 UI 显示用户消息
        let userPart = MessagePart(id: UUID().uuidString, type: .text, text: text, tool: nil, error: nil)
        let userInfo = MessageInfo(
            id: UUID().uuidString,
            role: "user",
            sessionID: sessionID,
            time: MessageInfo.MessageTime(created: Date().timeIntervalSince1970 * 1000,
                                            completed: Date().timeIntervalSince1970 * 1000),
            cost: nil, tokens: nil
        )
        messages.append(MessageResponse(info: userInfo, parts: [userPart]))

        // 创建一个空的 assistant 消息占位（用于流式填充）
        let assistantInfo = MessageInfo(
            id: UUID().uuidString,
            role: "assistant",
            sessionID: sessionID,
            time: nil, cost: nil, tokens: nil
        )
        let assistantMessage = MessageResponse(info: assistantInfo, parts: [])
        messages.append(assistantMessage)
        streamingMessageID = assistantMessage.id

        // 注册 SSE 事件处理
        setupSSEHandler()

        // 启动灵动岛实时活动
        liveActivity.startStreaming(sessionID: sessionID, sessionTitle: sessionTitle)
        updateWidgetSnapshot()

        do {
            try await apiClient.sendAsyncMessage(sessionID: sessionID, text: text)
        } catch let error as APIError {
            errorMessage = error.errorDescription
            isStreaming = false
            liveActivity.end(status: .failed)
            updateWidgetSnapshot()
        } catch {
            errorMessage = error.localizedDescription
            isStreaming = false
            liveActivity.end(status: .failed)
            updateWidgetSnapshot()
        }

        isSending = false
    }

    /// 中止当前会话
    func abortSession() async {
        do {
            try await apiClient.abortSession(sessionID: sessionID)
            isStreaming = false
            streamingText = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - SSE 实时更新

    private func setupSSEHandler() {
        sseClient.onEvent = { [weak self] event in
            Task { @MainActor in
                self?.handleSSEEvent(event)
            }
        }
    }

    private func handleSSEEvent(_ event: SSEEvent) {
        // 只处理当前会话的事件
        let eventSessionID = event.properties.sessionID
        guard eventSessionID == sessionID || eventSessionID == nil else { return }

        switch event.type {
        case .messagePart:
            handleStreamPart(event)
        case .messageUpdated:
            handleMessageUpdated(event)
        case .messageRemoved:
            handleMessageRemoved(event)
        default:
            break
        }
    }

    /// 处理流式 Part 事件 — 逐步累积 AI 回复
    private func handleStreamPart(_ event: SSEEvent) {
        guard let part = event.properties.part else { return }

        if let messageID = event.properties.messageID {
            streamingMessageID = messageID
        }

        // 查找或创建 assistant 消息
        if let idx = messages.firstIndex(where: { $0.id == streamingMessageID }) {
            var updatedMessage = messages[idx]

            if part.type == .text || part.type == .reason {
                // 文本 Part: 累积到流式文本
                streamingText += part.displayText

                // 实时更新灵动岛
                liveActivity.update(text: streamingText, status: .streaming)
                updateWidgetSnapshot()

                // 更新消息
                let textPart = MessagePart(
                    id: part.id, type: part.type,
                    text: streamingText, tool: nil, error: nil
                )
                updatedMessage = MessageResponse(
                    info: updatedMessage.info,
                    parts: [textPart]
                )
                messages[idx] = updatedMessage
            } else {
                // 非文本 Part (工具调用等): 追加
                updatedMessage = MessageResponse(
                    info: updatedMessage.info,
                    parts: updatedMessage.parts + [part]
                )
                messages[idx] = updatedMessage
            }
        }
    }

    /// 消息更新完成 — 从服务器拉取完整消息
    private func handleMessageUpdated(_ event: SSEEvent) {
        guard let messageID = event.properties.messageID else { return }

        isStreaming = false
        streamingText = ""
        liveActivity.end(status: .completed)
        updateWidgetSnapshot()

        // 从服务器拉取最新完整消息列表
        Task {
            await fetchMessages()
        }
    }

    /// 消息被删除
    private func handleMessageRemoved(_ event: SSEEvent) {
        guard let messageID = event.properties.messageID else { return }
        messages.removeAll { $0.info.id == messageID }
    }

    // MARK: - 小组件快照同步

    /// 将当前聊天状态写入 App Group, 供小组件读取展示
    private func updateWidgetSnapshot() {
        var snapshot = SharedStore.readSnapshot() ?? .empty
        snapshot.liveActivityRunning = isStreaming
        let latestPreview = messages.last?
            .parts
            .filter { $0.isTextType }
            .map { $0.displayText }
            .joined(separator: "\n") ?? ""
        snapshot.latestMessagePreview = String(latestPreview.prefix(120)).isEmpty ? "还没有消息" : String(latestPreview.prefix(120))
        snapshot.currentStatusText = isStreaming ? "AI 正在生成..." : "就绪"
        snapshot.timestamp = Date()
        SharedStore.updateSnapshot(snapshot)
    }

    // MARK: - 拉取增量 (从后台恢复时)

    func fetchIncrementalMessages() async {
        await fetchMessages()
    }

    // MARK: - 辅助

    /// 合并显示某条消息的所有文本 Part
    func displayText(for message: MessageResponse) -> String {
        message.parts
            .filter { $0.isTextType }
            .map { $0.displayText }
            .joined(separator: "\n")
    }

    /// 是否为用户消息
    func isUserMessage(_ message: MessageResponse) -> Bool {
        message.info.role == "user"
    }

    /// 会话中的工具调用列表
    func toolCalls(for message: MessageResponse) -> [MessagePart] {
        message.parts.filter { $0.isToolType }
    }
}

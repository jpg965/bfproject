import Foundation

// MARK: - SSEClient
// Server-Sent Events 客户端
// 用于实时接收 opencode 事件流 (GET /event)
//
// iOS 注意事项:
// - iOS 在 App 进入后台时会挂起/断开 URLSession 连接
// - 本客户端设计为: 前台保持 SSE 连接, 后台由 AppLifecycleManager 通知断开
// - 后台时改用 APIClient 轮询消息列表
// - 回到前台时自动重连 SSE
//
// 实现: 使用原生 URLSession.bytes (iOS 15+) 进行流式读取
// 可选替换为 loopwork-ai/EventSource (Swift 6.0+) 以获得更完整的 SSE 规范支持

@Observable
final class SSEClient {
    // MARK: - 公开状态

    var isConnected = false
    var lastEventTime: Date?       // 最后收到事件的时间 (用于心跳检测)

    // MARK: - 事件回调

    var onEvent: ((SSEEvent) -> Void)?
    var onConnect: (() -> Void)?
    var onDisconnect: ((Error?) -> Void)?

    // MARK: - 私有属性

    private var task: Task<Void, Never>?
    private var heartbeatTask: Task<Void, Never>?
    private var urlSession: URLSession?
    private var baseURL: URL?
    private var authHeader: String?

    // 自动重连配置
    private var reconnectDelay: TimeInterval = 2.0
    private var maxReconnectDelay: TimeInterval = 30.0
    private var shouldReconnect = false

    // 心跳超时: 超过此时间无事件则判定连接已断
    private let heartbeatTimeout: TimeInterval = 60.0
    // 心跳检查间隔
    private let heartbeatCheckInterval: TimeInterval = 15.0

    // 统计
    private var totalEventsReceived = 0
    private var reconnectCount = 0

    // MARK: - Init

    init() {
        let config = URLSessionConfiguration.default
        // SSE 是长连接, 不设请求超时
        config.timeoutIntervalForRequest = .infinity
        config.timeoutIntervalForResource = .infinity
        config.allowsCellularAccess = true
        config.allowsExpensiveNetworkAccess = true
        self.urlSession = URLSession(configuration: config)
    }

    // MARK: - 连接管理

    /// 连接到 opencode SSE 事件流
    func connect(config: ServerConfig, password: String?) {
        guard !config.hostname.isEmpty else { return }

        let scheme = config.useHTTPS ? "https" : "http"
        guard let url = URL(string: "\(scheme)://\(config.hostname):\(config.port)/event") else { return }
        self.baseURL = url

        // 构建 Basic Auth header
        if let password = password, !password.isEmpty {
            let credentials = "\(config.username):\(password)"
            if let credentialData = credentials.data(using: .utf8) {
                self.authHeader = "Basic \(credentialData.base64EncodedString())"
            }
        } else {
            self.authHeader = nil
        }

        shouldReconnect = true
        startStream()
        startHeartbeatMonitor()
    }

    /// 主动断开连接（不自动重连）
    func disconnect() {
        shouldReconnect = false
        stopHeartbeatMonitor()
        task?.cancel()
        task = nil
        if isConnected {
            isConnected = false
            onDisconnect?(nil)
        }
    }

    /// 后台暂停（不自动重连，由 AppLifecycleManager 调用）
    func pause() {
        shouldReconnect = false
        stopHeartbeatMonitor()
        task?.cancel()
        task = nil
        isConnected = false
    }

    /// 前台恢复（自动重连）
    func resume(config: ServerConfig, password: String?) {
        connect(config: config, password: password)
    }

    // MARK: - SSE 流处理

    private func startStream() {
        task?.cancel()

        guard let url = baseURL else { return }

        task = Task { [weak self] in
            guard let self = self else { return }

            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
            request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
            if let authHeader = self.authHeader {
                request.setValue(authHeader, forHTTPHeaderField: "Authorization")
            }

            do {
                guard let urlSession = self.urlSession else { return }

                // 使用 URLSession.bytes 进行流式读取 (iOS 15+)
                let (bytes, response) = try await urlSession.bytes(for: request)

                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    await self.handleDisconnect(error: APIError.httpError(
                        statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0,
                        body: nil
                    ))
                    self.scheduleReconnect()
                    return
                }

                await MainActor.run {
                    self.isConnected = true
                    self.reconnectDelay = 2.0  // 重置重连延迟
                    self.lastEventTime = Date()
                    self.onConnect?()
                }

                // 逐行解析 SSE 格式
                // SSE 规范: 事件由多个字段行组成, 以空行分隔
                // 字段: event:, data:, id:, retry:
                var eventType = ""
                var dataLines: [String] = []
                var lastEventID = ""

                for try await line in bytes.lines {
                    if Task.isCancelled { break }

                    // SSE 注释行 (以 : 开头) — 常用作心跳
                    if line.hasPrefix(":") {
                        // 更新最后活动时间 (心跳)
                        await MainActor.run {
                            self.lastEventTime = Date()
                        }
                        continue
                    }

                    if line.hasPrefix("event:") {
                        eventType = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                    } else if line.hasPrefix("data:") {
                        let data = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                        dataLines.append(data)
                    } else if line.hasPrefix("id:") {
                        lastEventID = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                    } else if line.isEmpty {
                        // 空行 = 事件结束，处理累积的事件
                        if !dataLines.isEmpty {
                            let data = dataLines.joined(separator: "\n")
                            self.processSSEEvent(eventType: eventType, data: data,
                                                  eventID: lastEventID)
                            eventType = ""
                            dataLines = []
                        }
                    }
                }

                // 流正常结束或被中断
                if !Task.isCancelled && self.shouldReconnect {
                    await self.handleDisconnect(error: nil)
                    self.scheduleReconnect()
                }

            } catch {
                if !Task.isCancelled && self.shouldReconnect {
                    await self.handleDisconnect(error: error)
                    self.scheduleReconnect()
                }
            }
        }
    }

    // MARK: - 事件解析

    private func processSSEEvent(eventType: String, data: String, eventID: String) {
        guard let jsonData = data.data(using: .utf8) else { return }

        // 更新最后事件时间
        totalEventsReceived += 1

        Task { @MainActor in
            self.lastEventTime = Date()
        }

        // opencode SSE 的 data 字段包含 JSON 事件
        // 事件格式: { "type": "...", "properties": {...} }
        // 或直接是 properties 内容

        // 尝试直接解码为 SSEEvent
        if let event = try? JSONDecoder().decode(SSEEvent.self, from: jsonData) {
            Task { @MainActor in self.onEvent?(event) }
            return
        }

        // 如果直接解码失败, 构建包装结构
        var eventDict: [String: Any] = [:]
        if !eventType.isEmpty {
            eventDict["type"] = eventType
        }

        if let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
            // 如果 data 本身包含 type 和 properties
            if let type = json["type"] as? String {
                eventDict["type"] = type
            }
            if let properties = json["properties"] {
                eventDict["properties"] = properties
            } else {
                // 整个 JSON 作为 properties
                eventDict["properties"] = json
            }
        }

        guard let finalData = try? JSONSerialization.data(withJSONObject: eventDict),
              let event = try? JSONDecoder().decode(SSEEvent.self, from: finalData) else {
            // 无法解析的事件, 忽略
            return
        }

        Task { @MainActor in
            self.onEvent?(event)
        }
    }

    // MARK: - 心跳监控

    /// 启动心跳监控: 定期检查最后事件时间, 超时则重连
    private func startHeartbeatMonitor() {
        stopHeartbeatMonitor()

        heartbeatTask = Task { [weak self] in
            guard let self = self else { return }

            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(self.heartbeatCheckInterval * 1_000_000_000))

                if Task.isCancelled { break }

                guard let lastTime = await MainActor.run(body: { self.lastEventTime }),
                      await MainActor.run(body: { self.isConnected }) else { continue }

                let elapsed = Date().timeIntervalSince(lastTime)
                if elapsed > self.heartbeatTimeout {
                    // 心跳超时, 主动重连
                    print("SSE 心跳超时 (\(elapsed)s), 重连...")
                    await MainActor.run {
                        self.reconnectCount += 1
                    }
                    self.task?.cancel()
                    self.scheduleReconnect()
                    return
                }
            }
        }
    }

    private func stopHeartbeatMonitor() {
        heartbeatTask?.cancel()
        heartbeatTask = nil
    }

    // MARK: - 重连逻辑

    private func scheduleReconnect() {
        guard shouldReconnect else { return }

        let delay = reconnectDelay
        reconnectDelay = min(reconnectDelay * 2, maxReconnectDelay)  // 指数退避

        Task { [weak self] in
            guard let self = self else { return }
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard self.shouldReconnect else { return }
            self.startStream()
        }
    }

    @MainActor
    private func handleDisconnect(error: Error?) {
        self.isConnected = false
        self.onDisconnect?(error)
    }

    // MARK: - 统计信息

    /// 获取连接统计
    func getStats() -> (totalEvents: Int, reconnects: Int, isConnected: Bool) {
        (totalEventsReceived, reconnectCount, isConnected)
    }
}

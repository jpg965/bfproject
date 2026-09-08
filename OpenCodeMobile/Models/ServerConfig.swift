import Foundation

// MARK: - ServerConfig
// 服务器连接配置 — 存储在 AppStorage 中，密码存 Keychain

struct ServerConfig: Codable, Equatable {
    var hostname: String      // Tailscale IP 或域名, 如 "100.64.0.1"
    var port: Int             // 默认 4096
    var useHTTPS: Bool        // 是否使用 HTTPS (Tailscale 本身加密, 可用 HTTP)
    var username: String      // Basic Auth 用户名, 默认 "opencode"

    var baseURL: URL {
        let scheme = useHTTPS ? "https" : "http"
        return URL(string: "\(scheme)://\(hostname):\(port)")!
    }

    init(
        hostname: String = "",
        port: Int = 4096,
        useHTTPS: Bool = false,
        username: String = "opencode"
    ) {
        self.hostname = hostname
        self.port = port
        self.useHTTPS = useHTTPS
        self.username = username
    }
}

// MARK: - 服务器健康状态
// GET /global/health
struct ServerHealth: Codable {
    let healthy: Bool
    let version: String
}

// MARK: - 会话状态
// GET /session/status
// 返回 { [sessionID: string]: SessionStatus }
struct SessionStatus: Codable {
    let status: String  // "idle" | "running" | "waiting" 等

    enum CodingKeys: String, CodingKey {
        case status
    }
}

typealias SessionStatusResponse = [String: SessionStatus]

// MARK: - SSE 事件
// GET /event — Server-Sent Events
// 第一个事件是 server.connected, 之后是 bus events
// 完整事件类型参考 opencode 源码和 OpenAPI spec

struct SSEEvent: Codable {
    let type: EventType
    let properties: EventProperties

    enum EventType: String, Codable {
        // Session 事件
        case sessionCreated = "session.created"
        case sessionUpdated = "session.updated"
        case sessionDeleted = "session.deleted"

        // Message 事件
        case messagePart = "message.part"
        case messageUpdated = "message.updated"
        case messageRemoved = "message.removed"

        // Server 事件
        case serverConnected = "server.connected"
        case serverDisconnected = "server.disconnected"

        // Tool 事件
        case toolStart = "tool.start"
        case toolUpdate = "tool.update"
        case toolEnd = "tool.end"

        // Permission 事件
        case permissionRequest = "permission.request"
        case permissionResponse = "permission.response"

        // Todo 事件
        case todoUpdated = "todo.updated"

        // File 事件
        case fileUpdated = "file.updated"

        // Config 事件
        case configUpdated = "config.updated"

        // Provider 事件
        case providerConnected = "provider.connected"
        case providerDisconnected = "provider.disconnected"

        // LSP 事件
        case lspStatusChanged = "lsp.status_changed"

        // MCP 事件
        case mcpStatusChanged = "mcp.status_changed"

        // 未知事件
        case unknown

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let raw = try? container.decode(String.self)
            self = EventType(rawValue: raw ?? "") ?? .unknown
        }
    }

    struct EventProperties: Codable {
        // 通用属性
        let sessionID: String?
        let messageID: String?

        // Message 相关
        let part: MessagePart?
        let info: MessageInfo?

        // Tool 相关
        let toolID: String?
        let toolName: String?
        let toolInput: String?
        let toolOutput: String?

        // Permission 相关
        let permissionID: String?
        let permissionType: String?

        // Todo 相关
        let todoID: String?
        let todoContent: String?
        let todoStatus: String?

        // File 相关
        let filePath: String?
        let fileStatus: String?

        // Config / Provider 相关
        let providerID: String?
        let configKey: String?

        enum CodingKeys: String, CodingKey {
            case sessionID = "sessionID"
            case messageID = "messageID"
            case part
            case info
            case toolID = "toolID"
            case toolName = "toolName"
            case toolInput = "toolInput"
            case toolOutput = "toolOutput"
            case permissionID = "permissionID"
            case permissionType = "permissionType"
            case todoID = "todoID"
            case todoContent = "todoContent"
            case todoStatus = "todoStatus"
            case filePath = "filePath"
            case fileStatus = "fileStatus"
            case providerID = "providerID"
            case configKey = "configKey"
        }
    }

    /// 事件是否与当前会话相关
    func isForSession(_ sessionID: String) -> Bool {
        guard let eventSessionID = properties.sessionID else {
            return false // 全局事件
        }
        return eventSessionID == sessionID
    }

    /// 事件是否与当前消息相关
    func isForMessage(_ messageID: String) -> Bool {
        guard let eventMessageID = properties.messageID else {
            return false
        }
        return eventMessageID == messageID
    }
}

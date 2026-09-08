import Foundation

// MARK: - Message
// 对应 opencode API: GET /session/:id/message, POST /session/:id/message
// 文档: https://dev.opencode.ai/docs/server#messages

/// 消息元信息
struct MessageInfo: Codable, Identifiable, Hashable {
    let id: String
    let role: String        // "user" | "assistant"
    let sessionID: String
    let time: MessageTime?
    let cost: Double?
    let tokens: TokenInfo?

    enum CodingKeys: String, CodingKey {
        case id, role
        case sessionID = "sessionID"
        case time, cost, tokens
    }

    struct MessageTime: Codable, Hashable {
        let created: Double?
        let completed: Double?
    }

    struct TokenInfo: Codable, Hashable {
        let input: Int?
        let output: Int?
        let reasoning: Int?
        let cache: CacheInfo?

        struct CacheInfo: Codable, Hashable {
            let write: Int?
            let read: Int?
        }
    }

    var createdDate: Date? {
        guard let created = time?.created else { return nil }
        return Date(timeIntervalSince1970: created / 1000)
    }
}

/// 消息内容片段 — opencode 的消息由多个 Part 组成
/// Part 类型包括: text, tool_call, tool_result, reason, file 等
struct MessagePart: Codable, Identifiable, Hashable {
    let id: String
    let type: PartType
    let text: String?
    let tool: ToolCallInfo?
    let error: String?

    // 工具调用信息（当 type == .tool 或 .toolResult 时使用）
    struct ToolCallInfo: Codable, Hashable {
        let id: String?
        let name: String?
        let input: String?
        let output: String?
    }

    enum PartType: String, Codable {
        case text
        case reason = "reason"
        case tool = "tool"
        case toolResult = "tool_result"
        case file = "file"
        case unknown
    }

    enum CodingKeys: String, CodingKey {
        case id, type, text, tool, error
    }

    /// 该 Part 的显示文本
    var displayText: String {
        switch type {
        case .text:
            return text ?? ""
        case .reason:
            return text ?? ""
        case .tool:
            if let tool = tool {
                return "🔧 \(tool.name ?? "tool")"
            }
            return "🔧 Tool call"
        case .toolResult:
            if let tool = tool, let output = tool.output {
                let preview = String(output.prefix(200))
                return "📋 \(tool.name ?? "result"): \(preview)"
            }
            return "📋 Tool result"
        case .file:
            return "📎 \(text ?? "file")"
        case .unknown:
            return text ?? ""
        }
    }

    /// 是否为文本类型（需要 Markdown 渲染）
    var isTextType: Bool {
        type == .text || type == .reason
    }

    /// 是否为工具相关类型
    var isToolType: Bool {
        type == .tool || type == .toolResult
    }
}

/// API 返回的消息结构: { info: MessageInfo, parts: [MessagePart] }
struct MessageResponse: Codable, Identifiable {
    var id: String { info.id }
    let info: MessageInfo
    let parts: [MessagePart]
}

typealias MessageListResponse = [MessageResponse]

// MARK: - 发送消息请求体
// POST /session/:id/message
// body: { messageID?, model?, agent?, noReply?, system?, tools?, parts }

struct SendMessageRequest: Codable {
    let messageID: String?
    let model: String?
    let agent: String?
    let noReply: Bool?
    let parts: [SendMessagePart]

    struct SendMessagePart: Codable {
        let type: String
        let text: String

        init(text: String) {
            self.type = "text"
            self.text = text
        }
    }

    init(text: String, model: String? = nil, agent: String? = nil,
         messageID: String? = nil, noReply: Bool? = nil) {
        self.messageID = messageID
        self.model = model
        self.agent = agent
        self.noReply = noReply
        self.parts = [SendMessagePart(text: text)]
    }
}

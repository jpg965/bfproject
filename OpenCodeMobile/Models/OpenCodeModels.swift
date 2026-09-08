import Foundation

// MARK: - Agent
// GET /agent — 列出所有可用 agents
// 文档: https://dev.opencode.ai/docs/server#agents

struct Agent: Codable, Identifiable, Hashable {
    let name: String
    let description: String?
    let mode: String?          // "all" | "build" | "plan" 等
    let builtIn: Bool?
    let model: ModelRef?

    var id: String { name }

    struct ModelRef: Codable, Hashable {
        let providerID: String?
        let modelID: String?
    }
}

// MARK: - Provider
// GET /provider — 列出所有 LLM providers
// GET /config/providers — 列出 providers 和默认 models

struct Provider: Codable, Identifiable, Hashable {
    let id: String               // provider ID
    let models: [Model]?
    let configured: Bool?         // 是否已配置 API key

    struct Model: Codable, Identifiable, Hashable {
        let id: String           // model ID
        let name: String?
        let attachment: Bool?
        let reasoning: Bool?
        let cost: CostInfo?
        let limit: Int?          // 上下文窗口大小

        struct CostInfo: Codable, Hashable {
            let input: Double?
            let output: Double?
            let cacheWrite: Double?
            let cacheRead: Double?
        }
    }
}

/// GET /provider 完整响应
struct ProviderListResponse: Codable {
    let all: [Provider]
    let `default`: [String: String]    // [providerID: defaultModelID]
    let connected: [String]            // 已配置的 provider IDs
}

/// GET /provider/auth 响应
struct ProviderAuthResponse: Codable {
    // [providerID: [auth methods]]
    let auth: [String: [ProviderAuthMethod]]

    struct ProviderAuthMethod: Codable, Hashable {
        let id: String                // "api_key" | "oauth" 等
        let name: String?
        let description: String?
        let fields: [AuthField]?
        let url: String?              // OAuth URL

        struct AuthField: Codable, Hashable {
            let name: String          // "key" | "base_url" 等
            let placeholder: String?
            let description: String?
            let required: Bool?
            let secret: Bool?
            let `default`: String?
        }
    }
}

// MARK: - Command
// GET /command — 列出所有可用的 slash commands

struct Command: Codable, Identifiable, Hashable {
    let id: String
    let name: String?
    let description: String?
    let group: String?
    let keywords: [String]?
}

// MARK: - Config
// GET /config, PATCH /config

struct OpenCodeConfig: Codable, Hashable {
    let model: ModelRef?
    let agent: String?
    let provider: String?
    let theme: String?
    let smallModel: String?
    let largeModel: String?
    let reasonModel: String?
    let automaticGrouping: Bool?
    let share: Bool?
    let path: String?

    struct ModelRef: Codable, Hashable {
        let providerID: String?
        let modelID: String?
    }
}

/// GET /config/providers 响应
struct ConfigProvidersResponse: Codable {
    let providers: [Provider]
    let `default`: [String: String]  // [providerID: defaultModelID]
}

// MARK: - Project
// GET /project, GET /project/current

struct Project: Codable, Identifiable, Hashable {
    let id: String
    let path: String?
    let worktree: Bool?
    let settings: ProjectSettings?

    struct ProjectSettings: Codable, Hashable {
        let model: String?
        let agent: String?
        let provider: String?
    }
}

// MARK: - Path & VCS
// GET /path, GET /vcs

struct PathInfo: Codable, Hashable {
    let path: String
}

struct VcsInfo: Codable, Hashable {
    let branch: String?
    let dirty: Bool?
    let head: String?           // commit hash
    let name: String?           // remote name
    let root: String?           // repo root path
    let ahead: Int?             // commits ahead of remote
    let behind: Int?            // commits behind remote
}

// MARK: - Todo
// GET /session/:id/todo

struct Todo: Codable, Identifiable, Hashable {
    let id: String
    let content: String
    let status: TodoStatus
    let priority: String?

    enum TodoStatus: String, Codable {
        case pending
        case inProgress = "in_progress"
        case completed
        case cancelled
    }
}

// MARK: - File
// GET /file?path=, GET /file/content?path=, GET /file/status
// GET /find?pattern=, GET /find/file?query=, GET /find/symbol?query=

/// GET /file?path= — 文件/目录列表
struct FileNode: Codable, Identifiable, Hashable {
    let id = UUID()
    let name: String
    let path: String
    let isDirectory: Bool
    let size: Int?

    enum CodingKeys: String, CodingKey {
        case name, path, size
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.path = try container.decode(String.self, forKey: .path)
        self.size = try? container.decode(Int.self, forKey: .size)
        // opencode 用 "size" 为 -1 或缺失表示目录
        let sizeVal = try? container.decode(Int.self, forKey: .size)
        self.isDirectory = sizeVal == nil || sizeVal == -1
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(path, forKey: .path)
        try container.encode(size, forKey: .size)
    }
}

/// GET /file/status — 跟踪的文件状态
struct FileStatus: Codable, Identifiable, Hashable {
    let id = UUID()
    let path: String
    let status: String          // "modified" | "added" | "deleted" | "untracked" 等
    let staged: Bool?
    let diff: String?           // unified diff
}

/// GET /find?pattern= — 搜索文件内容
struct FindMatch: Codable, Identifiable, Hashable {
    let id = UUID()
    let path: String
    let lines: String
    let line_number: Int
    let absolute_offset: Int
    let submatches: [Submatch]

    struct Submatch: Codable, Hashable {
        let match: String
        let start: Int
        let end: Int
    }
}

/// GET /find/symbol?query= — 搜索 workspace symbols
struct Symbol: Codable, Identifiable, Hashable {
    let id = UUID()
    let name: String
    let kind: String
    let path: String
    let range: SymbolRange?

    struct SymbolRange: Codable, Hashable {
        let start: Position
        let end: Position

        struct Position: Codable, Hashable {
            let line: Int
            let character: Int
        }
    }
}

// MARK: - FileDiff & FileContent (从 APIClient.swift 迁移)

/// GET /session/:id/diff 返回的类型
struct FileDiff: Codable, Identifiable, Hashable {
    let id = UUID()
    let path: String
    let status: String          // "added" | "modified" | "deleted"
    let diff: String            // unified diff 内容
}

/// GET /file/content?path= 返回的类型
struct FileContent: Codable, Hashable {
    let path: String
    let content: String
    let size: Int?
}

// MARK: - LSP / Formatter / MCP
// GET /lsp, GET /formatter, GET /mcp

struct LSPStatus: Codable, Identifiable, Hashable {
    let id = UUID()
    let name: String
    let running: Bool
    let root: String?
}

struct FormatterStatus: Codable, Identifiable, Hashable {
    let id = UUID()
    let name: String
    let running: Bool
}

struct MCPStatus: Codable, Identifiable, Hashable {
    let id = UUID()
    let name: String
    let running: Bool
    let tools: [MCPTool]?

    struct MCPTool: Codable, Hashable {
        let name: String
        let description: String?
    }
}

// MARK: - Tools (Experimental)
// GET /experimental/tool/ids, GET /experimental/tool

struct ToolIDs: Codable, Hashable {
    let ids: [String]
}

struct ToolList: Codable, Hashable {
    let tools: [Tool]

    struct Tool: Codable, Identifiable, Hashable {
        let id = UUID()
        let name: String
        let description: String?
        let parameters: [String: AnyCodable]?
    }
}

// MARK: - AnyCodable (用于动态 JSON 值)

struct AnyCodable: Codable, Hashable {
    let value: Any

    init(_ value: Any) { self.value = value }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let int = try? container.decode(Int.self) { self.value = int }
        else if let double = try? container.decode(Double.self) { self.value = double }
        else if let bool = try? container.decode(Bool.self) { self.value = bool }
        else if let string = try? container.decode(String.self) { self.value = string }
        else if let array = try? container.decode([AnyCodable].self) { self.value = array.map { $0.value } }
        else if let dict = try? container.decode([String: AnyCodable].self) {
            self.value = dict.mapValues { $0.value }
        } else { self.value = NSNull() }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let v as Int: try container.encode(v)
        case let v as Double: try container.encode(v)
        case let v as Bool: try container.encode(v)
        case let v as String: try container.encode(v)
        case let v as [Any]: try container.encode(v.map { AnyCodable($0) })
        case let v as [String: Any]: try container.encode(v.mapValues { AnyCodable($0) })
        default: try container.encodeNil()
        }
    }

    static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        String(describing: lhs.value) == String(describing: rhs.value)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(String(describing: value))
    }
}

// MARK: - EmptyResponse
/// 用于 204 No Content 等空响应
struct EmptyResponse: Codable {}

// MARK: - Log
// POST /log

struct LogRequest: Codable {
    let service: String
    let level: String         // "info" | "warn" | "error" | "debug"
    let message: String
    let extra: [String: String]?
}

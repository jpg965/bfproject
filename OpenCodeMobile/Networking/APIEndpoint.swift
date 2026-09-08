import Foundation

// MARK: - APIEndpoint
// 封装 opencode REST API 全部端点
// 文档: https://dev.opencode.ai/docs/server

enum APIEndpoint {
    // MARK: Global
    case health                                    // GET /global/health
    case globalEvent                                // SSE: GET /global/event

    // MARK: Project
    case listProjects                               // GET /project
    case currentProject                              // GET /project/current

    // MARK: Path & VCS
    case currentPath                                // GET /path
    case vcsInfo                                    // GET /vcs

    // MARK: Instance
    case disposeInstance                            // POST /instance/dispose

    // MARK: Config
    case getConfig                                  // GET /config
    case updateConfig                               // PATCH /config
    case getConfigProviders                         // GET /config/providers

    // MARK: Provider
    case listProviders                              // GET /provider
    case providerAuth                               // GET /provider/auth
    case oauthAuthorize(providerID: String)         // POST /provider/{id}/oauth/authorize
    case oauthCallback(providerID: String)           // POST /provider/{id}/oauth/callback

    // MARK: Session
    case listSessions                                // GET /session
    case createSession                               // POST /session
    case session(id: String)                        // GET /session/:id
    case deleteSession(id: String)                   // DELETE /session/:id
    case sessionStatus                               // GET /session/status
    case sessionChildren(id: String)                 // GET /session/:id/children
    case sessionTodo(id: String)                     // GET /session/:id/todo
    case sessionInit(id: String)                     // POST /session/:id/init
    case forkSession(id: String)                     // POST /session/:id/fork
    case abortSession(id: String)                    // POST /session/:id/abort
    case shareSession(id: String)                    // POST /session/:id/share
    case unshareSession(id: String)                  // DELETE /session/:id/share
    case summarizeSession(id: String)                // POST /session/:id/summarize
    case revertMessage(id: String)                   // POST /session/:id/revert
    case unrevertMessages(id: String)                // POST /session/:id/unrevert

    // MARK: Message
    case listMessages(sessionID: String)              // GET /session/:id/message
    case sendMessage(sessionID: String)               // POST /session/:id/message
    case sendAsyncMessage(sessionID: String)           // POST /session/:id/prompt_async
    case messageDetail(sessionID: String, messageID: String) // GET /session/:id/message/:messageID
    case executeCommand(sessionID: String)             // POST /session/:id/command
    case runShellCommand(sessionID: String)            // POST /session/:id/shell

    // MARK: Session Diff & Permission
    case sessionDiff(sessionID: String)                // GET /session/:id/diff
    case respondPermission(sessionID: String, permissionID: String) // POST /session/:id/permissions/:permissionID

    // MARK: Event (SSE)
    case event                                         // SSE: GET /event

    // MARK: Commands
    case listCommands                                  // GET /command

    // MARK: File
    case listFiles(path: String)                       // GET /file?path=
    case fileContent(path: String)                    // GET /file/content?path=
    case fileStatus                                    // GET /file/status
    case findText(pattern: String)                     // GET /find?pattern=
    case findFile(query: String)                       // GET /find/file?query=
    case findSymbol(query: String)                     // GET /find/symbol?query=

    // MARK: Tools (Experimental)
    case listToolIDs                                   // GET /experimental/tool/ids
    case listTools(provider: String?, model: String?) // GET /experimental/tool?provider=&model=

    // MARK: LSP / Formatter / MCP
    case lspStatus                                      // GET /lsp
    case formatterStatus                               // GET /formatter
    case mcpStatus                                     // GET /mcp
    case addMCPServer                                  // POST /mcp

    // MARK: Agent
    case listAgents                                    // GET /agent

    // MARK: Logging
    case writeLog                                      // POST /log

    // MARK: TUI
    case tuiAppendPrompt                               // POST /tui/append-prompt
    case tuiOpenHelp                                   // POST /tui/open-help
    case tuiOpenSessions                               // POST /tui/open-sessions
    case tuiOpenThemes                                 // POST /tui/open-themes
    case tuiOpenModels                                 // POST /tui/open-models
    case tuiSubmitPrompt                               // POST /tui/submit-prompt
    case tuiClearPrompt                                // POST /tui/clear-prompt
    case tuiExecuteCommand                             // POST /tui/execute-command
    case tuiShowToast                                  // POST /tui/show-toast
    case tuiControlNext                                // GET /tui/control/next
    case tuiControlResponse                            // POST /tui/control/response

    // MARK: Auth
    case setAuth(providerID: String)                   // PUT /auth/:id

    // MARK: Docs
    case docs                                          // GET /doc

    // MARK: - Path

    var path: String {
        switch self {
        // Global
        case .health: return "/global/health"
        case .globalEvent: return "/global/event"

        // Project
        case .listProjects: return "/project"
        case .currentProject: return "/project/current"

        // Path & VCS
        case .currentPath: return "/path"
        case .vcsInfo: return "/vcs"

        // Instance
        case .disposeInstance: return "/instance/dispose"

        // Config
        case .getConfig: return "/config"
        case .updateConfig: return "/config"
        case .getConfigProviders: return "/config/providers"

        // Provider
        case .listProviders: return "/provider"
        case .providerAuth: return "/provider/auth"
        case .oauthAuthorize(let id): return "/provider/\(id)/oauth/authorize"
        case .oauthCallback(let id): return "/provider/\(id)/oauth/callback"

        // Session
        case .listSessions: return "/session"
        case .createSession: return "/session"
        case .session(let id): return "/session/\(id)"
        case .deleteSession(let id): return "/session/\(id)"
        case .sessionStatus: return "/session/status"
        case .sessionChildren(let id): return "/session/\(id)/children"
        case .sessionTodo(let id): return "/session/\(id)/todo"
        case .sessionInit(let id): return "/session/\(id)/init"
        case .forkSession(let id): return "/session/\(id)/fork"
        case .abortSession(let id): return "/session/\(id)/abort"
        case .shareSession(let id): return "/session/\(id)/share"
        case .unshareSession(let id): return "/session/\(id)/share"
        case .summarizeSession(let id): return "/session/\(id)/summarize"
        case .revertMessage(let id): return "/session/\(id)/revert"
        case .unrevertMessages(let id): return "/session/\(id)/unrevert"

        // Message
        case .listMessages(let sid): return "/session/\(sid)/message"
        case .sendMessage(let sid): return "/session/\(sid)/message"
        case .sendAsyncMessage(let sid): return "/session/\(sid)/prompt_async"
        case .messageDetail(let sid, let mid): return "/session/\(sid)/message/\(mid)"
        case .executeCommand(let sid): return "/session/\(sid)/command"
        case .runShellCommand(let sid): return "/session/\(sid)/shell"

        // Diff & Permission
        case .sessionDiff(let sid): return "/session/\(sid)/diff"
        case .respondPermission(let sid, let pid): return "/session/\(sid)/permissions/\(pid)"

        // Event
        case .event: return "/event"

        // Commands
        case .listCommands: return "/command"

        // File
        case .listFiles: return "/file"
        case .fileContent: return "/file/content"
        case .fileStatus: return "/file/status"
        case .findText: return "/find"
        case .findFile: return "/find/file"
        case .findSymbol: return "/find/symbol"

        // Tools
        case .listToolIDs: return "/experimental/tool/ids"
        case .listTools: return "/experimental/tool"

        // LSP / Formatter / MCP
        case .lspStatus: return "/lsp"
        case .formatterStatus: return "/formatter"
        case .mcpStatus: return "/mcp"
        case .addMCPServer: return "/mcp"

        // Agent
        case .listAgents: return "/agent"

        // Logging
        case .writeLog: return "/log"

        // TUI
        case .tuiAppendPrompt: return "/tui/append-prompt"
        case .tuiOpenHelp: return "/tui/open-help"
        case .tuiOpenSessions: return "/tui/open-sessions"
        case .tuiOpenThemes: return "/tui/open-themes"
        case .tuiOpenModels: return "/tui/open-models"
        case .tuiSubmitPrompt: return "/tui/submit-prompt"
        case .tuiClearPrompt: return "/tui/clear-prompt"
        case .tuiExecuteCommand: return "/tui/execute-command"
        case .tuiShowToast: return "/tui/show-toast"
        case .tuiControlNext: return "/tui/control/next"
        case .tuiControlResponse: return "/tui/control/response"

        // Auth
        case .setAuth(let id): return "/auth/\(id)"

        // Docs
        case .docs: return "/doc"
        }
    }

    // MARK: - HTTP Method

    var method: String {
        switch self {
        // GET
        case .health, .globalEvent, .listProjects, .currentProject,
             .currentPath, .vcsInfo,
             .getConfig, .getConfigProviders,
             .listProviders, .providerAuth,
             .listSessions, .session, .sessionStatus, .sessionChildren,
             .sessionTodo, .listMessages, .messageDetail, .sessionDiff,
             .event, .listCommands,
             .listFiles, .fileContent, .fileStatus,
             .findText, .findFile, .findSymbol,
             .listToolIDs, .listTools,
             .lspStatus, .formatterStatus, .mcpStatus,
             .listAgents, .docs, .tuiControlNext:
            return "GET"

        // POST
        case .disposeInstance, .createSession,
             .sessionInit, .forkSession, .abortSession,
             .shareSession, .summarizeSession,
             .revertMessage, .unrevertMessages,
             .sendMessage, .sendAsyncMessage, .executeCommand, .runShellCommand,
             .respondPermission, .oauthAuthorize, .oauthCallback,
             .addMCPServer, .writeLog,
             .tuiAppendPrompt, .tuiOpenHelp, .tuiOpenSessions, .tuiOpenThemes,
             .tuiOpenModels, .tuiSubmitPrompt, .tuiClearPrompt,
             .tuiExecuteCommand, .tuiShowToast, .tuiControlResponse:
            return "POST"

        // PATCH
        case .updateConfig:
            return "PATCH"

        // DELETE
        case .deleteSession, .unshareSession:
            return "DELETE"

        // PUT
        case .setAuth:
            return "PUT"
        }
    }

    // MARK: - Query Items

    /// 需要附加 query parameters 的端点返回其默认值
    var defaultQueryItems: [URLQueryItem] {
        switch self {
        case .listFiles(let path):
            return [URLQueryItem(name: "path", value: path)]
        case .fileContent(let path):
            return [URLQueryItem(name: "path", value: path)]
        case .findText(let pattern):
            return [URLQueryItem(name: "pattern", value: pattern)]
        case .findFile(let query):
            return [URLQueryItem(name: "query", value: query)]
        case .findSymbol(let query):
            return [URLQueryItem(name: "query", value: query)]
        case .listTools(let provider, let model):
            var items: [URLQueryItem] = []
            if let p = provider { items.append(URLQueryItem(name: "provider", value: p)) }
            if let m = model { items.append(URLQueryItem(name: "model", value: m)) }
            return items
        default:
            return []
        }
    }

    // MARK: - URL 构建

    /// 构建完整 URL（含默认 query items + 自定义 query items）
    func url(baseURL: URL, extraQueryItems: [URLQueryItem] = []) -> URL? {
        var path = self.path
        // 确保路径以 / 开头
        if !path.hasPrefix("/") { path = "/" + path }

        var components = URLComponents(
            url: baseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        )

        var items = defaultQueryItems
        items.append(contentsOf: extraQueryItems)
        if !items.isEmpty {
            components?.queryItems = items
        }

        return components?.url
    }
}

// MARK: - APIError

enum APIError: LocalizedError {
    case invalidURL
    case httpError(statusCode: Int, body: String?)
    case decodingError(Error)
    case networkError(Error)
    case serverError(String)
    case notConfigured
    case encodingError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的 URL"
        case .httpError(let code, let body):
            return "HTTP \(code): \(body ?? "无响应体")"
        case .decodingError(let error):
            return "数据解析错误: \(error.localizedDescription)"
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        case .serverError(let message):
            return "服务器错误: \(message)"
        case .notConfigured:
            return "请先在设置中配置服务器连接"
        case .encodingError(let error):
            return "请求编码错误: \(error.localizedDescription)"
        }
    }
}

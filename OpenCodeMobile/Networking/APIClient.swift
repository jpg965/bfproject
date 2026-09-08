import Foundation

// MARK: - APIClient
// 封装 opencode REST API 全部调用
// 负责: HTTP 请求构建、Basic Auth 认证、JSON 编解码、错误处理
// 文档: https://dev.opencode.ai/docs/server

@Observable
final class APIClient {
    var serverConfig: ServerConfig
    var password: String?

    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(serverConfig: ServerConfig = ServerConfig(), password: String? = nil) {
        self.serverConfig = serverConfig
        self.password = password

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 120
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config)

        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
    }

    // MARK: - 请求构建

    /// 构建 URLRequest，附带 Basic Auth 和默认 query items
    private func buildRequest(
        endpoint: APIEndpoint,
        body: Data? = nil,
        extraQueryItems: [URLQueryItem] = []
    ) throws -> URLRequest {
        guard !serverConfig.hostname.isEmpty else {
            throw APIError.notConfigured
        }

        guard let url = endpoint.url(baseURL: serverConfig.baseURL,
                                     extraQueryItems: extraQueryItems) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        // Basic Auth
        if let password = password, !password.isEmpty {
            let credentials = "\(serverConfig.username):\(password)"
            if let credentialData = credentials.data(using: .utf8) {
                let base64 = credentialData.base64EncodedString()
                request.setValue("Basic \(base64)", forHTTPHeaderField: "Authorization")
            }
        }

        if let body = body {
            request.httpBody = body
        }

        return request
    }

    /// 发送请求并解码响应（泛型版本）
    private func performRequest<T: Decodable>(
        endpoint: APIEndpoint,
        body: Data? = nil,
        extraQueryItems: [URLQueryItem] = []
    ) async throws -> T {
        let request = try buildRequest(endpoint: endpoint, body: body,
                                       extraQueryItems: extraQueryItems)

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.serverError("无效响应")
            }

            // 204 No Content (用于 prompt_async 等)
            if httpResponse.statusCode == 204 {
                if T.self == EmptyResponse.self {
                    return EmptyResponse() as! T
                }
                return try decoder.decode(T.self, from: Data("{}".utf8))
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                let bodyString = String(data: data, encoding: .utf8)
                throw APIError.httpError(statusCode: httpResponse.statusCode, body: bodyString)
            }

            // Bool 类型特殊处理 (opencode 返回 true/false)
            if T.self == Bool.self {
                let str = String(data: data, encoding: .utf8)?.lowercased() ?? ""
                return (str == "true" || str == "1") as! T
            }

            return try decoder.decode(T.self, from: data)
        } catch let error as APIError {
            throw error
        } catch let error as DecodingError {
            throw APIError.decodingError(error)
        } catch let error as EncodingError {
            throw APIError.encodingError(error)
        } catch {
            throw APIError.networkError(error)
        }
    }

    // MARK: - Global API

    /// 获取服务器健康状态
    /// GET /global/health → { healthy: true, version: string }
    func checkHealth() async throws -> ServerHealth {
        try await performRequest(endpoint: .health)
    }

    // MARK: - Project API

    /// 列出所有项目
    /// GET /project → [Project]
    func listProjects() async throws -> [Project] {
        try await performRequest(endpoint: .listProjects)
    }

    /// 获取当前项目
    /// GET /project/current → Project
    func getCurrentProject() async throws -> Project {
        try await performRequest(endpoint: .currentProject)
    }

    // MARK: - Path & VCS API

    /// 获取当前工作路径
    /// GET /path → { path: string }
    func getCurrentPath() async throws -> PathInfo {
        try await performRequest(endpoint: .currentPath)
    }

    /// 获取 VCS 信息（分支、提交状态等）
    /// GET /vcs → VcsInfo
    func getVCSInfo() async throws -> VcsInfo {
        try await performRequest(endpoint: .vcsInfo)
    }

    // MARK: - Instance API

    /// 销毁当前实例
    /// POST /instance/dispose → boolean
    func disposeInstance() async throws -> Bool {
        try await performRequest(endpoint: .disposeInstance)
    }

    // MARK: - Config API

    /// 获取配置
    /// GET /config → Config
    func getConfig() async throws -> OpenCodeConfig {
        try await performRequest(endpoint: .getConfig)
    }

    /// 更新配置
    /// PATCH /config → Config
    func updateConfig(_ config: OpenCodeConfig) async throws -> OpenCodeConfig {
        let body = try encoder.encode(config)
        return try await performRequest(endpoint: .updateConfig, body: body)
    }

    /// 获取所有 providers 和默认 models
    /// GET /config/providers → { providers, default }
    func getConfigProviders() async throws -> ConfigProvidersResponse {
        try await performRequest(endpoint: .getConfigProviders)
    }

    // MARK: - Provider API

    /// 列出所有 LLM providers
    /// GET /provider → { all, default, connected }
    func listProviders() async throws -> ProviderListResponse {
        try await performRequest(endpoint: .listProviders)
    }

    /// 获取 provider 认证方式
    /// GET /provider/auth → { [providerID]: [auth methods] }
    func getProviderAuth() async throws -> ProviderAuthResponse {
        try await performRequest(endpoint: .providerAuth)
    }

    /// OAuth 授权
    /// POST /provider/{id}/oauth/authorize
    func oauthAuthorize(providerID: String) async throws -> Bool {
        let body = try encoder.encode([String: AnyCodable]())
        return try await performRequest(
            endpoint: .oauthAuthorize(providerID: providerID), body: body
        )
    }

    /// OAuth 回调
    /// POST /provider/{id}/oauth/callback
    func oauthCallback(providerID: String) async throws -> Bool {
        let body = try encoder.encode([String: AnyCodable]())
        return try await performRequest(
            endpoint: .oauthCallback(providerID: providerID), body: body
        )
    }

    // MARK: - Session API

    /// 列出所有会话
    /// GET /session → [Session]
    func listSessions() async throws -> [Session] {
        try await performRequest(endpoint: .listSessions)
    }

    /// 创建新会话
    /// POST /session → Session
    func createSession(title: String? = nil, parentID: String? = nil) async throws -> Session {
        struct CreateBody: Codable {
            let title: String?
            let parentID: String?
        }
        let body = try encoder.encode(CreateBody(title: title, parentID: parentID))
        return try await performRequest(endpoint: .createSession, body: body)
    }

    /// 获取会话详情
    /// GET /session/:id → Session
    func getSession(id: String) async throws -> Session {
        try await performRequest(endpoint: .session(id: id))
    }

    /// 删除会话及其所有数据
    /// DELETE /session/:id → boolean
    func deleteSession(id: String) async throws -> Bool {
        try await performRequest(endpoint: .deleteSession(id: id))
    }

    /// 获取所有会话状态
    /// GET /session/status → { [sessionID]: SessionStatus }
    func getSessionStatus() async throws -> SessionStatusResponse {
        try await performRequest(endpoint: .sessionStatus)
    }

    /// 获取会话的子会话列表
    /// GET /session/:id/children → [Session]
    func getSessionChildren(id: String) async throws -> [Session] {
        try await performRequest(endpoint: .sessionChildren(id: id))
    }

    /// 获取会话的 Todo 列表
    /// GET /session/:id/todo → [Todo]
    func getSessionTodo(id: String) async throws -> [Todo] {
        try await performRequest(endpoint: .sessionTodo(id: id))
    }

    /// 初始化项目（分析代码并生成 AGENTS.md）
    /// POST /session/:id/init → boolean
    /// body: { messageID, providerID, modelID }
    func initSession(id: String, messageID: String? = nil,
                     providerID: String? = nil, modelID: String? = nil) async throws -> Bool {
        struct InitBody: Codable {
            let messageID: String?
            let providerID: String?
            let modelID: String?
        }
        let body = try encoder.encode(InitBody(messageID: messageID,
                                                providerID: providerID, modelID: modelID))
        return try await performRequest(endpoint: .sessionInit(id: id), body: body)
    }

    /// Fork 会话（从某条消息分叉创建新会话）
    /// POST /session/:id/fork → Session
    /// body: { messageID? }
    func forkSession(id: String, messageID: String? = nil) async throws -> Session {
        struct ForkBody: Codable { let messageID: String? }
        let body = try encoder.encode(ForkBody(messageID: messageID))
        return try await performRequest(endpoint: .forkSession(id: id), body: body)
    }

    /// 中止正在运行的会话
    /// POST /session/:id/abort → boolean
    func abortSession(sessionID: String) async throws -> Bool {
        try await performRequest(endpoint: .abortSession(id: sessionID))
    }

    /// 分享会话（生成分享链接）
    /// POST /session/:id/share → Session
    func shareSession(id: String) async throws -> Session {
        try await performRequest(endpoint: .shareSession(id: id))
    }

    /// 取消分享
    /// DELETE /session/:id/share → Session
    func unshareSession(id: String) async throws -> Session {
        try await performRequest(endpoint: .unshareSession(id: id))
    }

    /// 总结会话
    /// POST /session/:id/summarize → boolean
    /// body: { providerID, modelID }
    func summarizeSession(id: String, providerID: String,
                          modelID: String) async throws -> Bool {
        struct SumBody: Codable {
            let providerID: String
            let modelID: String
        }
        let body = try encoder.encode(SumBody(providerID: providerID, modelID: modelID))
        return try await performRequest(endpoint: .summarizeSession(id: id), body: body)
    }

    /// 撤销某条消息
    /// POST /session/:id/revert → boolean
    /// body: { messageID, partID? }
    func revertMessage(sessionID: String, messageID: String,
                       partID: String? = nil) async throws -> Bool {
        struct RevertBody: Codable {
            let messageID: String
            let partID: String?
        }
        let body = try encoder.encode(RevertBody(messageID: messageID, partID: partID))
        return try await performRequest(endpoint: .revertMessage(id: sessionID), body: body)
    }

    /// 恢复所有已撤销的消息
    /// POST /session/:id/unrevert → boolean
    func unrevertMessages(sessionID: String) async throws -> Bool {
        try await performRequest(endpoint: .unrevertMessages(id: sessionID))
    }

    // MARK: - Message API

    /// 获取会话中的消息列表
    /// GET /session/:id/message → [{ info, parts }]
    func listMessages(sessionID: String, limit: Int? = nil) async throws -> [MessageResponse] {
        var extraItems: [URLQueryItem] = []
        if let limit = limit {
            extraItems.append(URLQueryItem(name: "limit", value: String(limit)))
        }
        return try await performRequest(
            endpoint: .listMessages(sessionID: sessionID),
            extraQueryItems: extraItems
        )
    }

    /// 同步发送消息并等待回复
    /// POST /session/:id/message → { info, parts }
    func sendMessage(sessionID: String, text: String,
                     model: String? = nil, agent: String? = nil) async throws -> MessageResponse {
        let body = try encoder.encode(SendMessageRequest(text: text, model: model, agent: agent))
        return try await performRequest(endpoint: .sendMessage(sessionID: sessionID), body: body)
    }

    /// 异步发送消息（不等回复，通过 SSE 接收）
    /// POST /session/:id/prompt_async → 204 No Content
    func sendAsyncMessage(sessionID: String, text: String,
                          model: String? = nil, agent: String? = nil) async throws {
        let body = try encoder.encode(SendMessageRequest(text: text, model: model, agent: agent))
        let _: EmptyResponse = try await performRequest(
            endpoint: .sendAsyncMessage(sessionID: sessionID), body: body
        )
    }

    /// 获取单条消息详情
    /// GET /session/:id/message/:messageID → { info, parts }
    func getMessageDetail(sessionID: String, messageID: String) async throws -> MessageResponse {
        try await performRequest(endpoint: .messageDetail(sessionID: sessionID, messageID: messageID))
    }

    /// 执行 slash 命令
    /// POST /session/:id/command → { info, parts }
    /// body: { messageID?, agent?, model?, command, arguments }
    func executeCommand(sessionID: String, command: String,
                        arguments: [String] = [], agent: String? = nil,
                        model: String? = nil) async throws -> MessageResponse {
        struct CmdBody: Codable {
            let messageID: String?
            let agent: String?
            let model: String?
            let command: String
            let arguments: [String]
        }
        let body = try encoder.encode(CmdBody(
            messageID: nil, agent: agent, model: model,
            command: command, arguments: arguments
        ))
        return try await performRequest(endpoint: .executeCommand(sessionID: sessionID), body: body)
    }

    /// 运行 shell 命令
    /// POST /session/:id/shell → { info, parts }
    /// body: { agent, model?, command }
    func runShellCommand(sessionID: String, command: String,
                         agent: String, model: String? = nil) async throws -> MessageResponse {
        struct ShellBody: Codable {
            let agent: String
            let model: String?
            let command: String
        }
        let body = try encoder.encode(ShellBody(agent: agent, model: model, command: command))
        return try await performRequest(endpoint: .runShellCommand(sessionID: sessionID), body: body)
    }

    // MARK: - Diff & Permission API

    /// 获取会话的代码变更
    /// GET /session/:id/diff → [FileDiff]
    func getSessionDiff(sessionID: String, messageID: String? = nil) async throws -> [FileDiff] {
        var extraItems: [URLQueryItem] = []
        if let messageID = messageID {
            extraItems.append(URLQueryItem(name: "messageID", value: messageID))
        }
        return try await performRequest(
            endpoint: .sessionDiff(sessionID: sessionID),
            extraQueryItems: extraItems
        )
    }

    /// 回复权限请求
    /// POST /session/:id/permissions/:permissionID → boolean
    /// body: { response, remember? }
    func respondToPermission(sessionID: String, permissionID: String,
                             response: String, remember: Bool = false) async throws -> Bool {
        struct PermissionBody: Codable {
            let response: String
            let remember: Bool
        }
        let body = try encoder.encode(PermissionBody(response: response, remember: remember))
        return try await performRequest(
            endpoint: .respondPermission(sessionID: sessionID, permissionID: permissionID),
            body: body
        )
    }

    // MARK: - Command API

    /// 列出所有可用的 slash 命令
    /// GET /command → [Command]
    func listCommands() async throws -> [Command] {
        try await performRequest(endpoint: .listCommands)
    }

    // MARK: - File API

    /// 列出目录下的文件和目录
    /// GET /file?path= → [FileNode]
    func listFiles(path: String) async throws -> [FileNode] {
        try await performRequest(endpoint: .listFiles(path: path))
    }

    /// 读取文件内容
    /// GET /file/content?path= → FileContent
    func readFile(path: String) async throws -> FileContent {
        try await performRequest(endpoint: .fileContent(path: path))
    }

    /// 获取已跟踪文件的状态
    /// GET /file/status → [FileStatus]
    func getFileStatus() async throws -> [FileStatus] {
        try await performRequest(endpoint: .fileStatus)
    }

    /// 搜索文件内容（grep 风格）
    /// GET /find?pattern= → [FindMatch]
    func findText(pattern: String) async throws -> [FindMatch] {
        try await performRequest(endpoint: .findText(pattern: pattern))
    }

    /// 按名称搜索文件
    /// GET /find/file?query= → [string] (paths)
    func findFile(query: String, limit: Int = 50) async throws -> [String] {
        let extraItems = [URLQueryItem(name: "limit", value: String(limit))]
        return try await performRequest(
            endpoint: .findFile(query: query),
            extraQueryItems: extraItems
        )
    }

    /// 搜索 workspace symbols
    /// GET /find/symbol?query= → [Symbol]
    func findSymbol(query: String) async throws -> [Symbol] {
        try await performRequest(endpoint: .findSymbol(query: query))
    }

    // MARK: - Tools (Experimental) API

    /// 列出所有工具 ID
    /// GET /experimental/tool/ids → ToolIDs
    func listToolIDs() async throws -> ToolIDs {
        try await performRequest(endpoint: .listToolIDs)
    }

    /// 列出工具及 JSON schema
    /// GET /experimental/tool?provider=&model= → ToolList
    func listTools(provider: String? = nil, model: String? = nil) async throws -> ToolList {
        try await performRequest(endpoint: .listTools(provider: provider, model: model))
    }

    // MARK: - LSP / Formatter / MCP API

    /// 获取 LSP 服务器状态
    /// GET /lsp → [LSPStatus]
    func getLSPStatus() async throws -> [LSPStatus] {
        try await performRequest(endpoint: .lspStatus)
    }

    /// 获取格式化工具状态
    /// GET /formatter → [FormatterStatus]
    func getFormatterStatus() async throws -> [FormatterStatus] {
        try await performRequest(endpoint: .formatterStatus)
    }

    /// 获取 MCP 服务器状态
    /// GET /mcp → { [name]: MCPStatus }
    func getMCPStatus() async throws -> [String: MCPStatus] {
        try await performRequest(endpoint: .mcpStatus)
    }

    /// 动态添加 MCP 服务器
    /// POST /mcp → MCP status object
    /// body: { name, config }
    func addMCPServer(name: String, config: [String: AnyCodable]) async throws -> MCPStatus {
        struct MCPBody: Codable {
            let name: String
            let config: [String: AnyCodable]
        }
        let body = try encoder.encode(MCPBody(name: name, config: config))
        return try await performRequest(endpoint: .addMCPServer, body: body)
    }

    // MARK: - Agent API

    /// 列出所有可用 agents
    /// GET /agent → [Agent]
    func listAgents() async throws -> [Agent] {
        try await performRequest(endpoint: .listAgents)
    }

    // MARK: - Logging API

    /// 写入日志
    /// POST /log → boolean
    /// body: { service, level, message, extra? }
    func writeLog(service: String, level: String, message: String,
                  extra: [String: String]? = nil) async throws -> Bool {
        let body = try encoder.encode(LogRequest(service: service, level: level,
                                                   message: message, extra: extra))
        return try await performRequest(endpoint: .writeLog, body: body)
    }

    // MARK: - Auth API

    /// 设置 provider 认证凭证
    /// PUT /auth/:id → boolean
    func setAuth(providerID: String, credentials: [String: AnyCodable]) async throws -> Bool {
        let body = try encoder.encode(credentials)
        return try await performRequest(endpoint: .setAuth(providerID: providerID), body: body)
    }

    // MARK: - TUI API (用于远程驱动 TUI)

    /// 向 prompt 追加文本
    func tuiAppendPrompt(_ text: String) async throws -> Bool {
        struct Body: Codable { let text: String }
        let body = try encoder.encode(Body(text: text))
        return try await performRequest(endpoint: .tuiAppendPrompt, body: body)
    }

    /// 提交当前 prompt
    func tuiSubmitPrompt() async throws -> Bool {
        try await performRequest(endpoint: .tuiSubmitPrompt)
    }

    /// 清空 prompt
    func tuiClearPrompt() async throws -> Bool {
        try await performRequest(endpoint: .tuiClearPrompt)
    }

    /// 执行 TUI 命令
    func tuiExecuteCommand(_ command: String) async throws -> Bool {
        struct Body: Codable { let command: String }
        let body = try encoder.encode(Body(command: command))
        return try await performRequest(endpoint: .tuiExecuteCommand, body: body)
    }

    /// 显示 Toast 通知
    func tuiShowToast(title: String? = nil, message: String,
                      variant: String = "default") async throws -> Bool {
        struct Body: Codable {
            let title: String?
            let message: String
            let variant: String
        }
        let body = try encoder.encode(Body(title: title, message: message, variant: variant))
        return try await performRequest(endpoint: .tuiShowToast, body: body)
    }

    // MARK: - Docs API

    /// 获取 OpenAPI 3.1 规范页面
    /// GET /doc → HTML
    func getDocsURL() -> URL? {
        APIEndpoint.docs.url(baseURL: serverConfig.baseURL)
    }
}

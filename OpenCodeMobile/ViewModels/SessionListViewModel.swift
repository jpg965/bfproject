import Foundation
import SwiftUI

// MARK: - SessionListViewModel
// 管理会话列表: 拉取、创建、删除

@Observable
final class SessionListViewModel {
    var sessions: [Session] = []
    var isLoading = false
    var errorMessage: String?
    var sessionStatuses: [String: SessionStatus] = [:]

    private let apiClient: APIClient
    private let dataStore: DataStore
    private var sseClient: SSEClient

    init(apiClient: APIClient, dataStore: DataStore, sseClient: SSEClient) {
        self.apiClient = apiClient
        self.dataStore = dataStore
        self.sseClient = sseClient

        // 先加载缓存
        loadCachedSessions()

        // 监听 SSE 事件更新会话列表
        sseClient.onEvent = { [weak self] event in
            Task { @MainActor in
                self?.handleSSEEvent(event)
            }
        }
    }

    // MARK: - 加载

    /// 从本地缓存加载
    func loadCachedSessions() {
        let cached = dataStore.fetchSessions()
        sessions = cached.map { c in
            Session(
                id: c.id,
                title: c.title,
                parentID: c.parentID,
                share: nil,
                time: Session.SessionTime(
                    created: c.createdAt.timeIntervalSince1970 * 1000,
                    updated: c.updatedAt.timeIntervalSince1970 * 1000
                )
            )
        }
    }

    /// 从服务器拉取最新会话列表
    func fetchSessions() async {
        isLoading = true
        errorMessage = nil

        do {
            let remoteSessions = try await apiClient.listSessions()
            sessions = remoteSessions.sorted { (a, b) in
                let aTime = a.time?.updated ?? a.time?.created ?? 0
                let bTime = b.time?.updated ?? b.time?.created ?? 0
                return aTime > bTime
            }
            // 缓存到本地
            dataStore.upsertSessions(remoteSessions)

            // 同步会话数量到小组件快照
            var snapshot = SharedStore.readSnapshot() ?? .empty
            snapshot.sessionCount = remoteSessions.count
            SharedStore.updateSnapshot(snapshot)

            // 同时拉取会话状态
            await fetchSessionStatus()
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// 拉取会话运行状态
    func fetchSessionStatus() async {
        do {
            let status = try await apiClient.getSessionStatus()
            sessionStatuses = status
        } catch {
            // 静默处理
        }
    }

    // MARK: - 创建

    func createSession(title: String? = nil) async -> Session? {
        do {
            let session = try await apiClient.createSession(title: title)
            sessions.insert(session, at: 0)
            dataStore.upsertSession(session)
            return session
        } catch let error as APIError {
            errorMessage = error.errorDescription
            return nil
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    // MARK: - 删除

    func deleteSession(id: String) async {
        do {
            let success = try await apiClient.deleteSession(id: id)
            if success {
                sessions.removeAll { $0.id == id }
                dataStore.deleteSession(id: id)
            }
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - SSE 事件处理

    private func handleSSEEvent(_ event: SSEEvent) {
        switch event.type {
        case .sessionCreated:
            // 新会话创建, 重新拉取列表
            Task { await fetchSessions() }
        case .sessionUpdated:
            // 会话更新, 重新拉取
            Task { await fetchSessions() }
        case .sessionDeleted:
            if let sessionID = event.properties.sessionID {
                sessions.removeAll { $0.id == sessionID }
                dataStore.deleteSession(id: sessionID)
            }
        default:
            break
        }
    }

    // MARK: - 辅助

    /// 获取会话状态文本
    func statusText(for sessionID: String) -> String? {
        guard let status = sessionStatuses[sessionID] else { return nil }
        return status.status
    }

    /// 会话是否正在运行
    func isRunning(_ sessionID: String) -> Bool {
        statusText(for: sessionID) == "running"
    }
}

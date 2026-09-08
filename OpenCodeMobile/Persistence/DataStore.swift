import Foundation
import SwiftData

// MARK: - SwiftData 持久化模型
// 缓存会话和消息到本地，离线时可查看历史

@Model
final class CachedSession {
    @Attribute(.unique) var id: String
    var title: String?
    var parentID: String?
    var createdAt: Date
    var updatedAt: Date
    var lastMessagePreview: String?

    @Relationship(deleteRule: .cascade) var messages: [CachedMessage] = []

    init(id: String, title: String? = nil, parentID: String? = nil,
         createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.parentID = parentID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
final class CachedMessage {
    @Attribute(.unique) var id: String
    var sessionID: String
    var role: String        // "user" | "assistant"
    var textContent: String  // 合并后的文本内容
    var rawJSON: Data?       // 完整的原始消息 JSON, 用于恢复 Part 结构
    var createdAt: Date

    var session: CachedSession?

    init(id: String, sessionID: String, role: String,
         textContent: String, rawJSON: Data? = nil, createdAt: Date = Date()) {
        self.id = id
        self.sessionID = sessionID
        self.role = role
        self.textContent = textContent
        self.rawJSON = rawJSON
        self.createdAt = createdAt
    }
}

// MARK: - DataStore
// SwiftData 持久化管理器

@Observable
final class DataStore {
    private let container: ModelContainer
    private let context: ModelContext

    init() {
        do {
            container = try ModelContainer(
                for: CachedSession.self, CachedMessage.self,
                configurations: ModelConfiguration(schema: Schema([
                    CachedSession.self, CachedMessage.self
                ]))
            )
            context = container.mainContext
        } catch {
            fatalError("SwiftData 初始化失败: \(error)")
        }
    }

    // MARK: - Session 缓存

    /// 保存或更新会话
    func upsertSession(_ session: Session) {
        let sessionID = session.id
        let descriptor = FetchDescriptor<CachedSession>(
            predicate: #Predicate { $0.id == sessionID }
        )

        if let existing = try? context.fetch(descriptor).first {
            existing.title = session.title
            existing.parentID = session.parentID
            existing.updatedAt = session.createdDate ?? Date()
        } else {
            let cached = CachedSession(
                id: session.id,
                title: session.title,
                parentID: session.parentID,
                createdAt: session.createdDate ?? Date(),
                updatedAt: session.createdDate ?? Date()
            )
            context.insert(cached)
        }
        save()
    }

    /// 批量保存会话列表
    func upsertSessions(_ sessions: [Session]) {
        for session in sessions {
            upsertSession(session)
        }
    }

    /// 获取所有缓存的会话（按更新时间降序）
    func fetchSessions() -> [CachedSession] {
        let descriptor = FetchDescriptor<CachedSession>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// 删除会话
    func deleteSession(id: String) {
        let descriptor = FetchDescriptor<CachedSession>(
            predicate: #Predicate { $0.id == id }
        )
        if let session = try? context.fetch(descriptor).first {
            context.delete(session)
            save()
        }
    }

    // MARK: - Message 缓存

    /// 保存或更新消息
    func upsertMessage(_ message: MessageResponse) {
        let messageID = message.info.id
        let descriptor = FetchDescriptor<CachedMessage>(
            predicate: #Predicate { $0.id == messageID }
        )

        // 合并所有文本 Part 为显示文本
        let textContent = message.parts
            .filter { $0.isTextType }
            .map { $0.displayText }
            .joined(separator: "\n")

        // 保存原始 JSON 用于恢复完整结构
        let rawJSON = try? JSONEncoder().encode(message)

        if let existing = try? context.fetch(descriptor).first {
            existing.role = message.info.role
            existing.textContent = textContent
            existing.rawJSON = rawJSON
            existing.createdAt = message.info.createdDate ?? Date()
        } else {
            // 找到对应的 CachedSession
            let sessionID = message.info.sessionID
            let sessionDescriptor = FetchDescriptor<CachedSession>(
                predicate: #Predicate { $0.id == sessionID }
            )
            let session = try? context.fetch(sessionDescriptor).first

            let cached = CachedMessage(
                id: message.info.id,
                sessionID: message.info.sessionID,
                role: message.info.role,
                textContent: textContent,
                rawJSON: rawJSON,
                createdAt: message.info.createdDate ?? Date()
            )
            cached.session = session
            context.insert(cached)

            // 更新会话的最后消息预览
            session?.lastMessagePreview = String(textContent.prefix(100))
            session?.updatedAt = Date()
        }
        save()
    }

    /// 批量保存消息列表
    func upsertMessages(_ messages: [MessageResponse], for sessionID: String) {
        for message in messages {
            upsertMessage(message)
        }
        // 更新会话的最后消息预览
        let sessionDescriptor = FetchDescriptor<CachedSession>(
            predicate: #Predicate { $0.id == sessionID }
        )
        if let session = try? context.fetch(sessionDescriptor).first {
            session.lastMessagePreview = messages.last?.parts
                .filter { $0.isTextType }
                .map { $0.displayText }
                .joined(separator: "\n")
                .map { String($0.prefix(100)) }
            session.updatedAt = Date()
        }
        save()
    }

    /// 获取会话的所有缓存消息
    func fetchMessages(sessionID: String) -> [CachedMessage] {
        let descriptor = FetchDescriptor<CachedMessage>(
            predicate: #Predicate { $0.sessionID == sessionID },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    // MARK: - 清理

    private func save() {
        do {
            try context.save()
        } catch {
            print("SwiftData 保存失败: \(error)")
        }
    }
}

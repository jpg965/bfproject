import Foundation

// MARK: - Session
// 对应 opencode API: GET /session, POST /session, GET /session/:id
// 文档: https://dev.opencode.ai/docs/server#sessions

struct Session: Codable, Identifiable, Hashable {
    let id: String
    let title: String?
    let parentID: String?
    let share: ShareInfo?
    let time: SessionTime?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case parentID = "parentID"
        case share
        case time
    }

    struct ShareInfo: Codable, Hashable {
        let url: String?
    }

    struct SessionTime: Codable, Hashable {
        let created: Double?
        let updated: Double?
    }

    /// 格式化创建时间为易读字符串
    var createdDate: Date? {
        guard let created = time?.created else { return nil }
        return Date(timeIntervalSince1970: created / 1000)
    }

    /// 显示用的标题（如果无标题则显示截断的 ID）
    var displayTitle: String {
        title ?? "Session \(String(id.prefix(8)))"
    }
}

// MARK: - Session 列表响应
typealias SessionListResponse = [Session]

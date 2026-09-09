import Foundation

// MARK: - SharedStore
// App 与 Widget 之间通过 App Group 共享数据。
// Widget 无法直接访问主 App 的 UserDefaults / Keychain, 因此由 App 写入快照、Widget 读取快照。

enum SharedStore {
    /// App Group ID —— 与 entitlements 中的 application-groups 保持一致
    static let appGroupID = "group.com.opencode.remote"

    static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    // MARK: - 写入 (主 App 调用)

    static func updateSnapshot(_ snapshot: WidgetSnapshot) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(snapshot) else { return }
        defaults?.set(data, forKey: "widget.snapshot")
    }

    // MARK: - 读取 (Widget 调用)

    static func readSnapshot() -> WidgetSnapshot? {
        guard let data = defaults?.data(forKey: "widget.snapshot") else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(WidgetSnapshot.self, from: data)
    }

    static func clearSnapshot() {
        defaults?.removeObject(forKey: "widget.snapshot")
    }
}

/// 供小组件显示的当前状态快照
struct WidgetSnapshot: Codable {
    var isConnected: Bool
    var serverVersion: String?
    var sessionCount: Int
    var liveActivityRunning: Bool      // 是否有正在进行的实时活动 (AI 流式生成)
    var currentStatusText: String
    var latestMessagePreview: String
    var timestamp: Date

    static var empty: WidgetSnapshot {
        WidgetSnapshot(
            isConnected: false,
            serverVersion: nil,
            sessionCount: 0,
            liveActivityRunning: false,
            currentStatusText: "未连接",
            latestMessagePreview: "还没有会话记录",
            timestamp: Date()
        )
    }
}
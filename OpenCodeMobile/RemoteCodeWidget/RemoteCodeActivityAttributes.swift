import ActivityKit
import Foundation

// MARK: - RemoteCodeActivityAttributes
// 实时活动承载的数据类型。
// 本文件同时编译进「主 App」与「Widget Extension」两个 target, 保证类型一致。
// 灵动岛 + 锁屏 + 通知横幅均渲染此数据; pushType 为 nil 表示由 App 本地驱动更新。

struct RemoteCodeActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var status: LiveActivityStatus
        var text: String                 // 正在流式输出的文本 或 当前状态文本
        var sessionTitle: String
        var updatedAt: Date
    }

    var sessionID: String
    var sessionTitle: String
}

/// 实时活动所处阶段
enum LiveActivityStatus: String, Codable, Hashable {
    case streaming
    case waiting
    case completed
    case failed
}
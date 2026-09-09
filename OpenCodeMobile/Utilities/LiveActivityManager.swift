import ActivityKit
import Foundation

// MARK: - LiveActivityManager
// 负责 灵动岛 / 实时活动 (ActivityKit) 的启动、更新、结束。
// 说明:
// - 仅 iOS 16.1+ 且具备相应系统状态时可用; 模拟器与不支持的环境会静默降级为不启动。
// - pushType = nil 表示由 App 本地驱动内容更新 (无需 APNs)。

@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()

    private var activeActivity: Activity<RemoteCodeActivityAttributes>?

    private init() {}

    // MARK: - 系统支持检查

    var isSupported: Bool {
        #if targetEnvironment(simulator)
        return false   // 模拟器不渲染真实 Live Activities
        #else
        return ActivityAuthorizationInfo().areActivitiesEnabled
        #endif
    }

    /// 是否存在正在运行的实时活动
    var isActive: Bool {
        !Activity<RemoteCodeActivityAttributes>.activities.isEmpty
    }

    // MARK: - 启动 (AI 开始流式回复时)

    @discardableResult
    func startStreaming(sessionID: String, sessionTitle: String) {
        #if !targetEnvironment(simulator)
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        // 清理可能残留的旧活动, 避免同时出现在灵动岛上
        endAllCurrent()

        let attributes = RemoteCodeActivityAttributes(sessionID: sessionID, sessionTitle: sessionTitle)
        let state = RemoteCodeActivityAttributes.ContentState(
            status: .waiting,
            text: "",
            sessionTitle: sessionTitle,
            updatedAt: Date()
        )
        let content = ActivityContent(
            state: state,
            staleDate: nil,
            relevanceScore: 1.0
        )

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            activeActivity = activity
        } catch {
            print("启动实时活动失败: \(error.localizedDescription)")
        }
        #endif
    }

    // MARK: - 更新 (流式文本增长时)

    func update(text: String, status: LiveActivityStatus = .streaming) {
        let state = RemoteCodeActivityAttributes.ContentState(
            status: status,
            text: text,
            sessionTitle: activeActivity?.attributes.sessionTitle ?? "AI 生成中",
            updatedAt: Date()
        )
        let content = ActivityContent(state: state, staleDate: nil, relevanceScore: 1.0)
        Task {
            await activeActivity?.update(content)
        }
    }

    // MARK: - 结束 (AI 回复完成或失败)

    func end(status: LiveActivityStatus = .completed) {
        let state = RemoteCodeActivityAttributes.ContentState(
            status: status,
            text: status == .failed ? "AI 回复失败" : "AI 生成完成",
            sessionTitle: activeActivity?.attributes.sessionTitle ?? "",
            updatedAt: Date()
        )
        let content = ActivityContent(state: state, staleDate: nil, relevanceScore: 0.0)
        Task {
            for activity in Activity<RemoteCodeActivityAttributes>.activities {
                await activity.end(content, dismissalPolicy: .immediate)
            }
            activeActivity = nil
        }
    }

    /// 结束全部当前实时活动 (在新活动启动前清理)
    func endAllCurrent() {
        Task {
            for activity in Activity<RemoteCodeActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            activeActivity = nil
        }
    }

    // MARK: - 查询当前活动

    var currentActivity: Activity<RemoteCodeActivityAttributes>? {
        activeActivity
    }
}
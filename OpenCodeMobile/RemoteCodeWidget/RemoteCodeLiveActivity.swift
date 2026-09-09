import ActivityKit
import SwiftUI
import WidgetKit

// MARK: - RemoteCodeLiveActivity
// 灵动岛 + 锁屏 + 通知横幅 的实时活动渲染。
// 展示 AI 流式生成进度: 会话标题 + 当前文本 + 状态图标。

struct RemoteCodeLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RemoteCodeActivityAttributes.self) { context in
            // ---- 锁屏 / 通知横幅 ----
            HStack(spacing: 12) {
                statusIcon(state: context.state)
                VStack(alignment: .leading, spacing: 4) {
                    Text(context.attributes.sessionTitle)
                        .font(.headline)
                        .lineLimit(1)
                    Text(stateText(context.state))
                        .font(.subheadline)
                        .lineLimit(2)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if context.state.status == .streaming {
                    ProgressView()
                }
            }
            .padding(16)
            .activityBackgroundTint(Color.black.opacity(0.85))
            .activitySystemActionForegroundColor(.white)

        } dynamicIsland: { context in
            DynamicIsland {
                // ---- 展开视图 ----
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        statusIcon(state: context.state)
                        Text(context.attributes.sessionTitle)
                            .font(.subheadline).fontWeight(.semibold).lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.status == .streaming {
                        ProgressView().tint(.orange)
                    } else {
                        Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
                    }
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(stateText(context.state))
                        .font(.caption)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 8) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .foregroundStyle(.orange)
                        Text(context.attributes.sessionTitle)
                            .font(.caption2).opacity(0.7)
                        Spacer(minLength: 0)
                    }
                }
            } compactLeading: {
                Image(systemName: "terminal")
                    .foregroundStyle(.orange)
            } compactTrailing: {
                if context.state.status == .streaming {
                    ProgressView().tint(.orange)
                } else {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.green)
                }
            } minimal: {
                Image(systemName: "terminal")
                    .foregroundStyle(.orange)
            }
        }
    }

    // MARK: - 辅助

    private func stateText(_ state: RemoteCodeActivityAttributes.ContentState) -> String {
        switch state.status {
        case .streaming:
            return state.text.isEmpty ? "AI 正在生成..." : state.text
        case .waiting:
            return "正在等待 AI 回复..."
        case .completed:
            return "AI 生成完成"
        case .failed:
            return "AI 回复失败"
        }
    }

    @ViewBuilder
    private func statusIcon(state: RemoteCodeActivityAttributes.ContentState) -> some View {
        switch state.status {
        case .streaming:
            Image(systemName: "waveform")
                .symbolEffect(.variableColor.iterative, isActive: true)
                .foregroundStyle(.orange)
        case .waiting:
            ProgressView().tint(.orange)
        case .completed:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .failed:
            Image(systemName: "xmark.octagon.fill").foregroundStyle(.red)
        }
    }
}
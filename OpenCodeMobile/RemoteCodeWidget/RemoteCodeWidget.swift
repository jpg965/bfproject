import SwiftUI
import WidgetKit

// MARK: - RemoteCodeProvider
// 从 App Group 读取 App 写入的 WidgetSnapshot, 生成 Timeline 快照

struct RemoteCodeProvider: TimelineProvider {
    func placeholder(in context: Context) -> RemoteCodeEntry {
        RemoteCodeEntry(date: Date(), snapshot: .empty)
    }

    func getSnapshot(in context: Context, completion: @escaping (RemoteCodeEntry) -> Void) {
        let entry = RemoteCodeEntry(date: Date(), snapshot: SharedStore.readSnapshot() ?? .empty)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RemoteCodeEntry>) -> Void) {
        let snapshot = SharedStore.readSnapshot() ?? .empty
        var entries: [RemoteCodeEntry] = []
        // 每小时刷新一次; 更实时的内容由 App 主动写入快照
        for hourOffset in 0..<12 {
            let date = Calendar.current.date(byAdding: .hour, value: hourOffset, to: Date()) ?? Date()
            entries.append(RemoteCodeEntry(date: date, snapshot: snapshot))
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct RemoteCodeEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

// MARK: - RemoteCodeWidgetEntryView

struct RemoteCodeWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: RemoteCodeEntry

    var body: some View {
        switch family {
        case .systemSmall: smallView
        case .systemMedium: mediumView
        default: largeView
        }
    }

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            Spacer(minLength: 4)
            Text(entry.snapshot.currentStatusText)
                .font(.headline)
                .lineLimit(1)
            Text(entry.snapshot.latestMessagePreview)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(for: .widget) { Color.black }
    }

    private var mediumView: some View {
        HStack(alignment: .top, spacing: 12) {
            statusBadge
            VStack(alignment: .leading, spacing: 6) {
                header
                Text(entry.snapshot.currentStatusText)
                    .font(.subheadline).fontWeight(.semibold).lineLimit(1)
                Text(entry.snapshot.latestMessagePreview)
                    .font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
        .containerBackground(for: .widget) { Color.black }
    }

    private var largeView: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            Divider()
            HStack {
                Label("会话", systemImage: "bubble.left.and.bubble.right")
                Spacer()
                Text("\(entry.snapshot.sessionCount)")
            }
            .font(.subheadline)
            if let version = entry.snapshot.serverVersion {
                Label("OpenCode v\(version)", systemImage: "server.rack")
                    .font(.subheadline)
            }
            Text(entry.snapshot.latestMessagePreview)
                .font(.caption).foregroundStyle(.secondary).lineLimit(3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(for: .widget) { Color.black }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: entry.snapshot.isConnected ? "wifi" : "wifi.slash")
                .foregroundStyle(entry.snapshot.isConnected ? Color.green : Color.secondary)
            Text("Remote Code")
                .font(.caption).fontWeight(.bold)
            if entry.snapshot.liveActivityRunning {
                Circle().fill(Color.orange).frame(width: 6, height: 6)
            }
            Spacer(minLength: 0)
        }
    }

    private var statusBadge: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.15))
            Image(systemName: entry.snapshot.liveActivityRunning ? "dot.radiowaves.up.forward" : "terminal")
                .font(.title2)
                .foregroundStyle(entry.snapshot.liveActivityRunning ? Color.orange : Color.secondary)
        }
        .frame(width: 44, height: 88)
    }
}

// MARK: - RemoteCodeWidget (小组件)

struct RemoteCodeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "RemoteCodeWidget", provider: RemoteCodeProvider()) { entry in
            RemoteCodeWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Remote Code")
        .description("实时查看与 OpenCode 服务器的连接状态与最新会话。")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
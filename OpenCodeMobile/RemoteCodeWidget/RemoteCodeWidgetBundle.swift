import SwiftUI
import WidgetKit

// MARK: - RemoteCodeWidgetBundle
// Widget Extension 入口, 同时注册「小组件」与「实时活动」

@main
struct RemoteCodeWidgetBundle: WidgetBundle {
    var body: some Widget {
        RemoteCodeWidget()
        RemoteCodeLiveActivity()
    }
}
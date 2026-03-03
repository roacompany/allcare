import SwiftUI
import WidgetKit

/// 잠금화면 원형 위젯 — 수유 간격 게이지
struct LockScreenCircularView: View {
    let entry: BabyCareEntry

    var body: some View {
        Gauge(value: min(entry.feedingProgress, 1.0)) {
            Image(systemName: "cup.and.saucer.fill")
        } currentValueLabel: {
            Text(entry.feedingElapsedText)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(entry.isFeedingOverdue ? .red : .primary)
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .tint(entry.isFeedingOverdue ? .red : .blue)
        .widgetURL(URL(string: "babycare://record/feeding"))
    }
}

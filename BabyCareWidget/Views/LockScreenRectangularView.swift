import SwiftUI
import WidgetKit

/// 잠금화면 직사각형 위젯 — 3줄 요약
struct LockScreenRectangularView: View {
    let entry: BabyCareEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // 1줄: 다음 수유 예측
            HStack(spacing: 4) {
                Image(systemName: entry.isFeedingOverdue ? "exclamationmark.circle.fill" : "cup.and.saucer.fill")
                    .font(.caption2)
                Text(entry.isFeedingOverdue ? "수유 시간이 지났어요!" : "다음 수유 \(entry.nextFeedingText)")
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
            }

            // 2줄: 최근 기록 요약
            HStack(spacing: 6) {
                if let feeding = entry.lastFeedingTime {
                    Text("수유 \(WidgetTimeHelper.shortTimeAgo(feeding, from: entry.date))")
                        .font(.caption2)
                }
                if let sleep = entry.lastSleepTime {
                    Text("수면 \(WidgetTimeHelper.shortTimeAgo(sleep, from: entry.date))")
                        .font(.caption2)
                }
                if let diaper = entry.lastDiaperTime {
                    Text("기저귀 \(WidgetTimeHelper.shortTimeAgo(diaper, from: entry.date))")
                        .font(.caption2)
                }
            }
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        .widgetURL(URL(string: "babycare://record"))
    }
}

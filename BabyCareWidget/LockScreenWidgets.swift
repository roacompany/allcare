import WidgetKit
import SwiftUI

// MARK: - Enhanced Lock Screen Views (iOS 17+)
// 기존 BabyCareLockScreenWidget의 각 family에서 사용되는 뷰를 강화

// MARK: - Circular: 다음 수유까지 X분 (Gauge)

struct EnhancedLockScreenCircularView: View {
    let entry: BabyCareEntry

    var body: some View {
        if let next = entry.nextFeedingTime, next >= entry.date {
            let totalMinutes = entry.feedingIntervalMinutes
            let elapsed = entry.feedingElapsedMinutes
            let progress = totalMinutes > 0 ? min(Double(elapsed) / Double(totalMinutes), 1.0) : 0
            let remaining = Int(next.timeIntervalSince(entry.date) / 60)

            Gauge(value: progress) {
                Image(systemName: "cup.and.saucer.fill")
            } currentValueLabel: {
                Text("\(remaining)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .tint(remaining < 30 ? .orange : .blue)
            .widgetURL(URL(string: "babycare://record/feeding"))
        } else {
            // Overdue 또는 데이터 없음
            Gauge(value: entry.isFeedingOverdue ? 1.0 : 0.0) {
                Image(systemName: "cup.and.saucer.fill")
            } currentValueLabel: {
                Image(systemName: entry.isFeedingOverdue ? "exclamationmark" : "minus")
                    .font(.system(size: 10, weight: .bold))
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .tint(entry.isFeedingOverdue ? .red : .gray)
            .widgetURL(URL(string: "babycare://record/feeding"))
        }
    }
}

// MARK: - Rectangular: 오늘 요약 (3줄)

struct EnhancedLockScreenRectangularView: View {
    let entry: BabyCareEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // 1줄: 다음 수유 예측
            HStack(spacing: 4) {
                Image(
                    systemName: entry.isFeedingOverdue
                    ? "exclamationmark.circle.fill"
                    : "cup.and.saucer.fill"
                )
                .font(.caption2)
                Text(
                    entry.isFeedingOverdue
                    ? NSLocalizedString("widget.nextFeeding.overdue", comment: "")
                    : String(
                        format: NSLocalizedString("widget.nextFeeding.in", comment: ""),
                        entry.nextFeedingText
                      )
                )
                .font(.caption.weight(.semibold))
                .lineLimit(1)
            }
            .foregroundStyle(entry.isFeedingOverdue ? .red : .primary)

            // 2줄: 오늘 수유 횟수 · 수면 시간 · 기저귀 횟수
            HStack(spacing: 6) {
                Label(
                    String(
                        format: NSLocalizedString("widget.count.times", comment: ""),
                        entry.todayFeedingCount
                    ),
                    systemImage: "cup.and.saucer"
                )
                Label(entry.sleepDurationFormatted, systemImage: "moon.zzz")
                Label(
                    String(
                        format: NSLocalizedString("widget.count.times", comment: ""),
                        entry.todayDiaperCount
                    ),
                    systemImage: "drop"
                )
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)

            // 3줄: 아기 이름
            Text(entry.babyName)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .widgetURL(URL(string: "babycare://dashboard"))
    }
}

// MARK: - Inline: 다음 수유 시각

struct EnhancedLockScreenInlineView: View {
    let entry: BabyCareEntry

    var body: some View {
        if entry.isFeedingOverdue {
            Label(
                NSLocalizedString("widget.nextFeeding.overdue", comment: ""),
                systemImage: "exclamationmark.circle.fill"
            )
        } else if let next = entry.nextFeedingTime {
            Label(
                "\(NSLocalizedString("widget.nextFeeding.label", comment: "")) " + next.formatted(date: .omitted, time: .shortened),
                systemImage: "cup.and.saucer.fill"
            )
        } else {
            Text(entry.babyName + " · " + NSLocalizedString("widget.noRecord", comment: ""))
        }
    }
}

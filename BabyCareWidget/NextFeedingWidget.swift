import WidgetKit
import SwiftUI

// MARK: - NextFeedingWidget

struct NextFeedingWidget: Widget {
    let kind = "NextFeedingWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BabyCareProvider()) { entry in
            NextFeedingWidgetView(entry: entry)
        }
        .configurationDisplayName(NSLocalizedString("widget.nextFeeding.title", comment: ""))
        .description(NSLocalizedString("widget.nextFeeding.description", comment: ""))
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - NextFeedingWidgetView

struct NextFeedingWidgetView: View {
    let entry: BabyCareEntry
    @Environment(\.widgetFamily) var family
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        switch family {
        case .systemMedium:
            mediumView
        default:
            smallView
        }
    }

    // MARK: Small

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 헤더
            HStack(spacing: 4) {
                Image(systemName: "cup.and.saucer.fill")
                    .font(.caption2)
                    .foregroundStyle(WidgetColors.feeding(colorScheme))
                Text(NSLocalizedString("widget.nextFeeding.label", comment: ""))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Spacer()

            // 예측 시간
            if let next = entry.nextFeedingTime {
                if next < entry.date {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.red)
                    Text(NSLocalizedString("widget.nextFeeding.overdue", comment: ""))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.red)
                } else {
                    Text(entry.nextFeedingText)
                        .font(.title3.weight(.bold).monospacedDigit())
                        .foregroundStyle(WidgetColors.feedingText(colorScheme))
                        .minimumScaleFactor(0.7)
                        .lineLimit(2)

                    Text(next, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text(NSLocalizedString("widget.nextFeeding.noData", comment: ""))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // 아기 이름
            Text(entry.babyName)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .containerBackground(for: .widget) {
            ContainerRelativeShape()
                .fill(WidgetGradient.background(colorScheme))
        }
        .widgetURL(URL(string: "babycare://record/feeding"))
    }

    // MARK: Medium

    private var mediumView: some View {
        HStack(spacing: 16) {
            // Left: 다음 수유
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "cup.and.saucer.fill")
                        .foregroundStyle(WidgetColors.feeding(colorScheme))
                    Text(NSLocalizedString("widget.nextFeeding.label", comment: ""))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let next = entry.nextFeedingTime {
                    if next < entry.date {
                        Label(
                            NSLocalizedString("widget.nextFeeding.overdue", comment: ""),
                            systemImage: "exclamationmark.circle.fill"
                        )
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.red)
                    } else {
                        Text(entry.nextFeedingText)
                            .font(.title3.weight(.bold).monospacedDigit())
                            .foregroundStyle(WidgetColors.feedingText(colorScheme))
                            .minimumScaleFactor(0.7)
                        Text(next, style: .time)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text(NSLocalizedString("widget.nextFeeding.noData", comment: ""))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(entry.babyName)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Divider()
                .overlay(WidgetColors.divider(colorScheme))

            // Right: 오늘 수유 통계
            VStack(alignment: .leading, spacing: 8) {
                statRow(
                    icon: "number",
                    label: NSLocalizedString("widget.feeding.count.today", comment: ""),
                    value: String(
                        format: NSLocalizedString("widget.count.times", comment: ""),
                        entry.todayFeedingCount
                    )
                )
                if entry.todayTotalMl > 0 {
                    statRow(
                        icon: "drop.fill",
                        label: NSLocalizedString("widget.feeding.ml.today", comment: ""),
                        value: "\(Int(entry.todayTotalMl))ml"
                    )
                }
                if let last = entry.lastFeedingTime {
                    statRow(
                        icon: "clock",
                        label: NSLocalizedString("widget.feeding.last", comment: ""),
                        value: WidgetTimeHelper.timeAgo(last, from: entry.date)
                    )
                }
            }
        }
        .containerBackground(for: .widget) {
            ContainerRelativeShape()
                .fill(WidgetGradient.background(colorScheme))
        }
        .widgetURL(URL(string: "babycare://record/feeding"))
    }

    private func statRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(WidgetColors.feeding(colorScheme))
                .frame(width: 14)
            VStack(alignment: .leading, spacing: 0) {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.caption.weight(.semibold))
            }
        }
    }
}

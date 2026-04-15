import WidgetKit
import SwiftUI

// MARK: - TodaySummaryWidget

struct TodaySummaryWidget: Widget {
    let kind = "TodaySummaryWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BabyCareProvider()) { entry in
            TodaySummaryWidgetView(entry: entry)
        }
        .configurationDisplayName(NSLocalizedString("widget.todaySummary.title", comment: ""))
        .description(NSLocalizedString("widget.todaySummary.description", comment: ""))
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - TodaySummaryWidgetView

struct TodaySummaryWidgetView: View {
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
        VStack(alignment: .leading, spacing: 6) {
            // 헤더
            HStack {
                Text(NSLocalizedString("widget.todaySummary.label", comment: ""))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(entry.babyName)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            // 수유
            summaryRow(
                icon: "cup.and.saucer.fill",
                color: WidgetColors.feeding(colorScheme),
                value: String(
                    format: NSLocalizedString("widget.count.times", comment: ""),
                    entry.todayFeedingCount
                ),
                label: NSLocalizedString("widget.summary.feeding", comment: "")
            )

            // 수면
            summaryRow(
                icon: "moon.zzz.fill",
                color: WidgetColors.sleep(colorScheme),
                value: entry.sleepDurationFormatted,
                label: NSLocalizedString("widget.summary.sleep", comment: "")
            )

            // 기저귀
            summaryRow(
                icon: "humidity.fill",
                color: WidgetColors.diaper(colorScheme),
                value: String(
                    format: NSLocalizedString("widget.count.times", comment: ""),
                    entry.todayDiaperCount
                ),
                label: NSLocalizedString("widget.summary.diaper", comment: "")
            )
        }
        .containerBackground(for: .widget) {
            ContainerRelativeShape()
                .fill(WidgetGradient.background(colorScheme))
        }
        .widgetURL(URL(string: "babycare://dashboard"))
    }

    // MARK: Medium

    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 헤더
            HStack {
                Text(NSLocalizedString("widget.todaySummary.label", comment: ""))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(WidgetColors.feedingText(colorScheme))
                Spacer()
                Text(entry.babyName)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            // 요약 카드 3개
            HStack(spacing: 10) {
                summaryCard(
                    icon: "cup.and.saucer.fill",
                    color: WidgetColors.feeding(colorScheme),
                    title: NSLocalizedString("widget.summary.feeding", comment: ""),
                    value: String(
                        format: NSLocalizedString("widget.count.times", comment: ""),
                        entry.todayFeedingCount
                    ),
                    sub: entry.todayTotalMl > 0 ? "\(Int(entry.todayTotalMl))ml" : nil
                )
                summaryCard(
                    icon: "moon.zzz.fill",
                    color: WidgetColors.sleep(colorScheme),
                    title: NSLocalizedString("widget.summary.sleep", comment: ""),
                    value: entry.sleepDurationFormatted,
                    sub: nil
                )
                summaryCard(
                    icon: "humidity.fill",
                    color: WidgetColors.diaper(colorScheme),
                    title: NSLocalizedString("widget.summary.diaper", comment: ""),
                    value: String(
                        format: NSLocalizedString("widget.count.times", comment: ""),
                        entry.todayDiaperCount
                    ),
                    sub: nil
                )
            }

            // 다음 수유 예측 배너
            HStack(spacing: 4) {
                Image(systemName: entry.isFeedingOverdue ? "exclamationmark.circle.fill" : "clock.arrow.circlepath")
                    .font(.caption2)
                    .foregroundStyle(entry.isFeedingOverdue ? .red : WidgetColors.feeding(colorScheme))
                Text(entry.isFeedingOverdue
                     ? NSLocalizedString("widget.nextFeeding.overdue", comment: "")
                     : String(
                        format: NSLocalizedString("widget.nextFeeding.in", comment: ""),
                        entry.nextFeedingText
                     )
                )
                .font(.caption2.weight(.medium))
                .foregroundStyle(entry.isFeedingOverdue ? .red : .primary)
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        entry.isFeedingOverdue
                        ? Color.red.opacity(0.1)
                        : WidgetColors.feeding(colorScheme).opacity(0.12)
                    )
            )
        }
        .containerBackground(for: .widget) {
            ContainerRelativeShape()
                .fill(WidgetGradient.background(colorScheme))
        }
        .widgetURL(URL(string: "babycare://dashboard"))
    }

    // MARK: - Components

    private func summaryRow(icon: String, color: Color, value: String, label: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(color)
                .frame(width: 14)
            Text(value)
                .font(.caption.weight(.bold))
                .foregroundStyle(.primary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func summaryCard(
        icon: String,
        color: Color,
        title: String,
        value: String,
        sub: String?
    ) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
            Text(title)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            if let sub {
                Text(sub)
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(WidgetColors.cardBackground(colorScheme).opacity(0.8))
        )
    }
}

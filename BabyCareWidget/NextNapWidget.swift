import WidgetKit
import SwiftUI

// MARK: - NextNapWidget

struct NextNapWidget: Widget {
    let kind = "NextNapWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BabyCareProvider()) { entry in
            NextNapWidgetView(entry: entry)
        }
        .configurationDisplayName(NSLocalizedString("widget.nextNap.title", comment: ""))
        .description(NSLocalizedString("widget.nextNap.description", comment: ""))
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - NextNapWidgetView

struct NextNapWidgetView: View {
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
                Image(systemName: "moon.zzz.fill")
                    .font(.caption2)
                    .foregroundStyle(WidgetColors.sleep(colorScheme))
                Text(NSLocalizedString("widget.nextNap.label", comment: ""))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Spacer()

            // 낮잠 예측
            if let nap = entry.napPrediction, let nextNap = nap.nextNapTime {
                if nextNap < entry.date {
                    Image(systemName: "moon.zzz.fill")
                        .font(.title2)
                        .foregroundStyle(WidgetColors.sleep(colorScheme))
                    Text(NSLocalizedString("widget.nextNap.time", comment: ""))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(WidgetColors.sleep(colorScheme))
                } else {
                    Text(entry.nextNapText)
                        .font(.title3.weight(.bold).monospacedDigit())
                        .foregroundStyle(WidgetColors.sleep(colorScheme))
                        .minimumScaleFactor(0.7)
                        .lineLimit(2)

                    Text(nextNap, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                Image(systemName: "moon.zzz")
                    .font(.title2)
                    .foregroundStyle(WidgetColors.sleep(colorScheme).opacity(0.5))
                Text(NSLocalizedString("widget.nextNap.noData", comment: ""))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(entry.babyName)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .containerBackground(for: .widget) {
            ContainerRelativeShape()
                .fill(WidgetGradient.background(colorScheme))
        }
        .widgetURL(URL(string: "babycare://record/sleep"))
    }

    // MARK: Medium

    private var mediumView: some View {
        HStack(spacing: 16) {
            // Left: 다음 낮잠
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "moon.zzz.fill")
                        .foregroundStyle(WidgetColors.sleep(colorScheme))
                    Text(NSLocalizedString("widget.nextNap.label", comment: ""))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let nap = entry.napPrediction, let nextNap = nap.nextNapTime {
                    if nextNap < entry.date {
                        Label(
                            NSLocalizedString("widget.nextNap.time", comment: ""),
                            systemImage: "moon.zzz.fill"
                        )
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(WidgetColors.sleep(colorScheme))
                    } else {
                        Text(entry.nextNapText)
                            .font(.title3.weight(.bold).monospacedDigit())
                            .foregroundStyle(WidgetColors.sleep(colorScheme))
                            .minimumScaleFactor(0.7)
                        Text(nextNap, style: .time)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text(NSLocalizedString("widget.nextNap.noData", comment: ""))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(entry.babyName)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Divider()
                .overlay(WidgetColors.divider(colorScheme))

            // Right: 수면 통계
            VStack(alignment: .leading, spacing: 8) {
                statRow(
                    icon: "moon.fill",
                    label: NSLocalizedString("widget.sleep.today", comment: ""),
                    value: entry.sleepDurationFormatted
                )
                if let last = entry.lastSleepTime {
                    statRow(
                        icon: "clock",
                        label: NSLocalizedString("widget.sleep.last", comment: ""),
                        value: WidgetTimeHelper.timeAgo(last, from: entry.date)
                    )
                }
                if let duration = entry.lastSleepDuration {
                    statRow(
                        icon: "timer",
                        label: NSLocalizedString("widget.sleep.duration", comment: ""),
                        value: duration
                    )
                }
            }
        }
        .containerBackground(for: .widget) {
            ContainerRelativeShape()
                .fill(WidgetGradient.background(colorScheme))
        }
        .widgetURL(URL(string: "babycare://record/sleep"))
    }

    private func statRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(WidgetColors.sleep(colorScheme))
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

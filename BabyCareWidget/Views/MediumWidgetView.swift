import SwiftUI
import WidgetKit

struct MediumWidgetView: View {
    let entry: BabyCareEntry
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 16) {
            // Left: Baby info + 다음 수유
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.babyName)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(WidgetColors.feedingText(colorScheme))

                if !entry.babyAge.isEmpty {
                    Text(entry.babyAge)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if entry.isFeedingOverdue {
                    Label("수유 시간!", systemImage: "exclamationmark.circle.fill")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.red)
                } else {
                    Text("다음 수유")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(entry.nextFeedingText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(WidgetColors.feedingText(colorScheme))
                }
            }

            Divider()
                .overlay(WidgetColors.divider(colorScheme))

            // Right: Activity summary
            VStack(alignment: .leading, spacing: 8) {
                activityRow(
                    icon: "cup.and.saucer.fill",
                    color: WidgetColors.feeding(colorScheme),
                    label: entry.lastFeedingType ?? "수유",
                    time: entry.lastFeedingTime
                )
                activityRow(
                    icon: "moon.zzz.fill",
                    color: WidgetColors.sleep(colorScheme),
                    label: "수면",
                    time: entry.lastSleepTime
                )
                activityRow(
                    icon: "humidity.fill",
                    color: WidgetColors.diaper(colorScheme),
                    label: "기저귀",
                    time: entry.lastDiaperTime
                )
            }
        }
        .containerBackground(for: .widget) {
            ContainerRelativeShape()
                .fill(WidgetGradient.background(colorScheme))
        }
        .widgetURL(URL(string: "babycare://record"))
    }

    private func activityRow(icon: String, color: Color, label: String, time: Date?) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 0) {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(time.map { WidgetTimeHelper.timeAgo($0, from: entry.date) } ?? "-")
                    .font(.caption.weight(.medium))
            }
        }
    }
}

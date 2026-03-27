import SwiftUI
import WidgetKit

struct SmallWidgetView: View {
    let entry: BabyCareEntry
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(entry.babyName)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(WidgetColors.feedingText(colorScheme))
                Spacer()
                Image(systemName: "heart.fill")
                    .foregroundStyle(WidgetColors.feeding(colorScheme))
                    .font(.caption)
            }

            Spacer()

            if let lastFeeding = entry.lastFeedingTime {
                HStack(spacing: 4) {
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.caption2)
                        .foregroundStyle(WidgetColors.feeding(colorScheme))
                    Text(WidgetTimeHelper.timeAgo(lastFeeding, from: entry.date))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if entry.nextFeedingTime != nil {
                HStack(spacing: 4) {
                    Image(systemName: entry.isFeedingOverdue ? "exclamationmark.circle.fill" : "clock.fill")
                        .font(.caption2)
                        .foregroundStyle(entry.isFeedingOverdue ? .red : WidgetColors.sleep(colorScheme))
                    Text(entry.isFeedingOverdue ? "수유 시간!" : entry.nextFeedingText)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(entry.isFeedingOverdue ? .red : .primary)
                }
            }
        }
        .containerBackground(for: .widget) {
            ContainerRelativeShape()
                .fill(WidgetGradient.background(colorScheme))
        }
        .widgetURL(URL(string: "babycare://record/feeding"))
    }
}

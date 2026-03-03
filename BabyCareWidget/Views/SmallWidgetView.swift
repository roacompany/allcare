import SwiftUI
import WidgetKit

struct SmallWidgetView: View {
    let entry: BabyCareEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(entry.babyName)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color(hex: "FF6B8A"))
                Spacer()
                Image(systemName: "heart.fill")
                    .foregroundStyle(Color(hex: "FF9FB5"))
                    .font(.caption)
            }

            Spacer()

            if let lastFeeding = entry.lastFeedingTime {
                HStack(spacing: 4) {
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.caption2)
                        .foregroundStyle(Color(hex: "FF9FB5"))
                    Text(WidgetTimeHelper.timeAgo(lastFeeding, from: entry.date))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if entry.nextFeedingTime != nil {
                HStack(spacing: 4) {
                    Image(systemName: entry.isFeedingOverdue ? "exclamationmark.circle.fill" : "clock.fill")
                        .font(.caption2)
                        .foregroundStyle(entry.isFeedingOverdue ? .red : Color(hex: "7B9FE8"))
                    Text(entry.isFeedingOverdue ? "수유 시간!" : entry.nextFeedingText)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(entry.isFeedingOverdue ? .red : .primary)
                }
            }
        }
        .containerBackground(for: .widget) {
            ContainerRelativeShape()
                .fill(WidgetGradient.pastel)
        }
        .widgetURL(URL(string: "babycare://record/feeding"))
    }
}

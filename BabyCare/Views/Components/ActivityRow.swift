import SwiftUI

struct ActivityRow: View {
    let activity: Activity

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: activity.type.icon)
                .font(.title3)
                .foregroundStyle(colorForType(activity.type))
                .frame(width: 40, height: 40)
                .background(colorForType(activity.type).opacity(0.15))
                .clipShape(Circle())

            // Details
            VStack(alignment: .leading, spacing: 2) {
                Text(activity.type.displayName)
                    .font(.subheadline.weight(.medium))

                HStack(spacing: 8) {
                    Text(DateFormatters.shortTime.string(from: activity.startTime))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let duration = activity.durationText {
                        Text(duration)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let amount = activity.amountText {
                        Text(amount)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let side = activity.side {
                        Text(side.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let temp = activity.temperature {
                        Text(temp.temperatureText)
                            .font(.caption)
                            .foregroundStyle(temp >= 38.0 ? .red : .secondary)
                    }

                    if let med = activity.medicationName {
                        Text(med)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            // Time ago
            Text(activity.startTime.timeAgo())
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    private func colorForType(_ type: Activity.ActivityType) -> Color {
        switch type.category {
        case .feeding: Color(hex: "FF9FB5")
        case .sleep: Color(hex: "9FB5FF")
        case .diaper: Color(hex: "FFD59F")
        case .health: Color(hex: "D59FFF")
        }
    }
}

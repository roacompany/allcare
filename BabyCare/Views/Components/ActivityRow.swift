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

                    if let dosage = activity.medicationDosage {
                        Text(dosage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let food = activity.foodName {
                        Text(food)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    if let foodAmt = activity.foodAmount {
                        Text(foodAmt)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let reaction = activity.foodReaction {
                        Text(reaction.displayName)
                            .font(.caption)
                            .foregroundStyle(reaction.needsAttention ? .red : .secondary)
                    }

                    if let color = activity.stoolColor {
                        HStack(spacing: 2) {
                            Circle()
                                .fill(Color(hex: color.colorHex))
                                .frame(width: 10, height: 10)
                            Text(color.displayName)
                                .font(.caption)
                                .foregroundStyle(color.needsAttention ? .red : .secondary)
                        }
                    }

                    if let quality = activity.sleepQuality {
                        Text(quality.displayName)
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
        case .feeding: AppColors.feedingColor
        case .sleep: AppColors.sleepColor
        case .diaper: AppColors.diaperColor
        case .health: AppColors.medicationColor
        }
    }
}

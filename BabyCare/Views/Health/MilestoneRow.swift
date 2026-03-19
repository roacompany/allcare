import SwiftUI

// MARK: - Milestone Row

struct MilestoneRow: View {
    let milestone: Milestone
    let babyAgeMonths: Int

    private var isOverdue: Bool {
        !milestone.isAchieved && (milestone.expectedAgeMonths ?? 99) < babyAgeMonths
    }

    private var isCurrent: Bool {
        guard let m = milestone.expectedAgeMonths, !milestone.isAchieved else { return false }
        return m >= babyAgeMonths && m <= babyAgeMonths + 3
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: milestone.isAchieved ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(iconColor)
                .font(.title3)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(milestone.title)
                        .font(.subheadline.weight(.medium))
                        .strikethrough(milestone.isAchieved, color: .secondary)
                        .foregroundStyle(milestone.isAchieved ? .secondary : .primary)

                    if isOverdue {
                        Text("지연")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(.orange))
                    } else if isCurrent {
                        Text("지금")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(.blue))
                    }
                }

                if let months = milestone.expectedAgeMonths {
                    Text("생후 \(months)개월")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let desc = milestone.description {
                    Text(desc)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                if milestone.isAchieved, let date = milestone.achievedDate {
                    Text("달성일: \(DateFormatters.shortDate.string(from: date))")
                        .font(.caption)
                        .foregroundStyle(AppColors.successColor)
                }
            }

            Spacer()

            if milestone.isAchieved {
                Image(systemName: "star.fill")
                    .font(.caption)
                    .foregroundStyle(AppColors.diaperColor)
            }
        }
        .padding(.vertical, 2)
    }

    private var iconColor: Color {
        if milestone.isAchieved { return AppColors.successColor }
        if isOverdue { return .orange }
        return .secondary
    }
}

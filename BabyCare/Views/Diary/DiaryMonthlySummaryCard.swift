import SwiftUI

// MARK: - Diary Monthly Summary Card

struct DiaryMonthlySummaryCard: View {
    let summary: MonthlyMoodDistribution

    private var monthTitle: String {
        "\(summary.month)월 일기 요약"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Label(monthTitle, systemImage: "calendar.badge.clock")
                    .font(.subheadline.bold())
                    .foregroundStyle(AppColors.primaryAccent)
                Spacer()
                Text(String(format: NSLocalizedString("diary.summary.writtenDays", comment: ""), summary.writtenDays))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if summary.totalEntries == 0 {
                Text(NSLocalizedString("diary.summary.empty", comment: ""))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                // Mood bars
                VStack(spacing: 6) {
                    ForEach(sortedMoodRatios(), id: \.mood) { item in
                        MoodBarRow(
                            emoji: item.emoji,
                            name: item.name,
                            ratio: item.ratio,
                            count: item.count
                        )
                    }
                }

                Divider()

                // Stats row
                HStack(spacing: 16) {
                    StatChip(
                        icon: "pencil.and.list.clipboard",
                        value: "\(summary.totalEntries)",
                        label: NSLocalizedString("diary.summary.entries", comment: "")
                    )
                    StatChip(
                        icon: "text.alignleft",
                        value: String(format: "%.0f", summary.averageContentLength),
                        label: NSLocalizedString("diary.summary.avgLength", comment: "")
                    )
                }
            }
        }
        .padding(16)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    private struct MoodItem {
        let mood: String
        let emoji: String
        let name: String
        let ratio: Double
        let count: Int
    }

    private func sortedMoodRatios() -> [MoodItem] {
        let all = DiaryEntry.Mood.allCases.compactMap { mood -> MoodItem? in
            let count = summary.moodCounts[mood.rawValue] ?? 0
            guard count > 0 else { return nil }
            return MoodItem(
                mood: mood.rawValue,
                emoji: mood.emoji,
                name: mood.displayName,
                ratio: summary.ratio(for: mood.rawValue),
                count: count
            )
        }
        return all.sorted { $0.count > $1.count }.prefix(4).map { $0 }
    }
}

// MARK: - Mood Bar Row

private struct MoodBarRow: View {
    let emoji: String
    let name: String
    let ratio: Double
    let count: Int

    var body: some View {
        HStack(spacing: 8) {
            Text(emoji)
                .font(.callout)
                .frame(width: 24)
            Text(name)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.15))
                        .frame(height: 6)
                    Capsule()
                        .fill(AppColors.primaryAccent.opacity(0.7))
                        .frame(width: geo.size.width * ratio, height: 6)
                }
            }
            .frame(height: 6)
            Text(String(format: "%.0f%%", ratio * 100))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 34, alignment: .trailing)
        }
    }
}

// MARK: - Stat Chip

private struct StatChip: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(AppColors.primaryAccent)
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.caption.bold())
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

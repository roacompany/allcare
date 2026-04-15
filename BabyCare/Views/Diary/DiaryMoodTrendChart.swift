import Charts
import SwiftUI

// MARK: - Diary Mood Trend Chart

struct DiaryMoodTrendChart: View {
    let trends: [MoodTrend]

    private var sortedTrends: [MoodTrend] {
        trends.sorted { lhs, rhs in
            if lhs.year != rhs.year { return lhs.year < rhs.year }
            if lhs.month != rhs.month { return lhs.month < rhs.month }
            return lhs.mood < rhs.mood
        }
    }

    private var availableMonths: [(year: Int, month: Int)] {
        let unique = Set(trends.map { "\($0.year)-\($0.month)" })
        return unique.sorted().compactMap { key -> (year: Int, month: Int)? in
            let parts = key.split(separator: "-").compactMap { Int($0) }
            guard parts.count == 2 else { return nil }
            return (year: parts[0], month: parts[1])
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(
                NSLocalizedString("diary.trend.title", comment: ""),
                systemImage: "chart.bar.fill"
            )
            .font(.subheadline.bold())
            .foregroundStyle(AppColors.indigoColor)

            if trends.isEmpty {
                Text(NSLocalizedString("diary.trend.empty", comment: ""))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else {
                Chart(sortedTrends) { trend in
                    BarMark(
                        x: .value("월", trend.monthLabel),
                        y: .value("비율", trend.ratio)
                    )
                    .foregroundStyle(by: .value("기분", moodDisplayName(trend.mood)))
                    .position(by: .value("기분", moodDisplayName(trend.mood)))
                }
                .chartForegroundStyleScale(moodColorScale())
                .chartXAxis {
                    AxisMarks(values: .automatic) { _ in
                        AxisValueLabel()
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        if let d = value.as(Double.self) {
                            AxisValueLabel {
                                Text(String(format: "%.0f%%", d * 100))
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .frame(height: 180)

                // Legend
                moodLegend()
            }
        }
        .padding(16)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    private func moodDisplayName(_ raw: String) -> String {
        DiaryEntry.Mood(rawValue: raw)?.displayName ?? raw
    }

    private func moodColorScale() -> KeyValuePairs<String, Color> {
        [
            "행복": AppColors.pastelYellow,
            "사랑": AppColors.pastelPink,
            "평온": AppColors.pastelMint,
            "피곤": AppColors.pastelBlue,
            "아픔": AppColors.coralColor,
            "칭얼": AppColors.softPurpleColor
        ]
    }

    @ViewBuilder
    private func moodLegend() -> some View {
        let moods = DiaryEntry.Mood.allCases.filter { mood in
            trends.contains { $0.mood == mood.rawValue }
        }
        if !moods.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(moods, id: \.self) { mood in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(moodColor(mood))
                                .frame(width: 8, height: 8)
                            Text(mood.emoji + mood.displayName)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    private func moodColor(_ mood: DiaryEntry.Mood) -> Color {
        switch mood {
        case .happy: AppColors.pastelYellow
        case .love: AppColors.pastelPink
        case .calm: AppColors.pastelMint
        case .tired: AppColors.pastelBlue
        case .sick: AppColors.coralColor
        case .fussy: AppColors.softPurpleColor
        }
    }
}

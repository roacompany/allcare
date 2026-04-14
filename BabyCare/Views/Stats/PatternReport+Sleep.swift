import SwiftUI
import Charts

extension PatternReportView {
    // MARK: - Sleep Section

    func sleepSection(_ s: SleepPattern) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("수면 패턴", systemImage: "moon.zzz.fill")
                .font(.headline)
                .foregroundStyle(sleepColor)

            HStack(spacing: 0) {
                statItem(value: String(format: "%.1f", s.dailyAverageHours), label: "일평균", unit: "시간")
                Divider().frame(height: 30)
                statItem(value: s.averageDuration.shortDuration, label: "1회 평균", unit: "")
                Divider().frame(height: 30)
                statItem(value: s.durationTrend.rawValue, label: "추세", unit: "")
            }

            // Daily hours chart
            if !s.dailyHours.isEmpty {
                Text("일별 추이")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Chart(s.dailyHours, id: \.date) { item in
                    BarMark(
                        x: .value("날짜", item.date, unit: .day),
                        y: .value("시간", item.hours)
                    )
                    .foregroundStyle(sleepColor.gradient)
                    .cornerRadius(4)
                }
                .chartYAxisLabel("시간")
                .frame(height: 160)
            }

            // Quality distribution
            if !s.qualityDistribution.isEmpty {
                Text("수면 질")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    ForEach(Activity.SleepQualityType.allCases, id: \.self) { quality in
                        if let count = s.qualityDistribution[quality] {
                            chipView(
                                icon: quality.icon,
                                text: "\(quality.displayName) \(count)",
                                color: sleepColor
                            )
                        }
                    }
                }
            }

            // Method distribution
            if !s.methodDistribution.isEmpty {
                Text("잠든 곳")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Activity.SleepMethodType.allCases, id: \.self) { method in
                            if let count = s.methodDistribution[method] {
                                chipView(
                                    icon: method.icon,
                                    text: "\(method.displayName) \(count)",
                                    color: sleepColor
                                )
                            }
                        }
                    }
                }
            }

            if vm.showComparison {
                comparisonRow(
                    current: s.dailyAverageHours,
                    previous: s.previousDailyAverageHours,
                    unit: "시간/일",
                    label: "일 평균"
                )
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }
}

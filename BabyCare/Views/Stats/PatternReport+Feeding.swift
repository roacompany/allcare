import SwiftUI
import Charts

extension PatternReportView {
    // MARK: - Feeding Section

    func feedingSection(_ f: FeedingPattern) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("수유 패턴", systemImage: "cup.and.saucer.fill")
                .font(.headline)
                .foregroundStyle(feedingColor)

            // Summary numbers
            HStack(spacing: 0) {
                statItem(value: "\(f.totalCount)", label: "총 횟수", unit: "회")
                Divider().frame(height: 30)
                statItem(value: String(format: "%.1f", f.dailyAverage), label: "일평균", unit: "회")
                if let interval = f.averageInterval {
                    Divider().frame(height: 30)
                    statItem(value: interval.shortDuration, label: "평균 간격", unit: "")
                }
            }

            // Daily trend chart
            if !f.dailyCounts.isEmpty {
                Text("일별 추이")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Chart(f.dailyCounts, id: \.date) { item in
                    BarMark(
                        x: .value("날짜", item.date, unit: .day),
                        y: .value("횟수", item.count)
                    )
                    .foregroundStyle(feedingColor.gradient)
                    .cornerRadius(4)
                }
                .chartYAxisLabel("회")
                .frame(height: 160)
            }

            // Peak hours
            if !f.peakHours.isEmpty {
                HStack(spacing: 4) {
                    Text("피크 시간대")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    ForEach(f.peakHours, id: \.self) { hour in
                        Text("\(hour)시")
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(feedingColor.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
                if let predictionText = vm.feedingPredictionText {
                    Text(predictionText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Breast vs Bottle
            if f.breastVsBottleRatio.breast + f.breastVsBottleRatio.bottle > 0 {
                HStack {
                    Text("모유/분유")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("모유 \(f.breastVsBottleRatio.breast)회")
                        .font(.caption.weight(.medium))
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text("분유 \(f.breastVsBottleRatio.bottle)회")
                        .font(.caption.weight(.medium))
                }
            }

            if f.totalMl > 0 {
                HStack {
                    Text("수유량")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("일평균 \(String(format: "%.0f", f.dailyMlAverage))ml")
                        .font(.caption.weight(.medium))
                }
            }

            if f.averageInterval != nil {
                HStack {
                    Text("간격 추세")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    trendBadge(f.intervalTrend)
                }
            }

            if vm.showComparison {
                comparisonRow(
                    current: f.dailyAverage,
                    previous: f.previousDailyAverage,
                    unit: "회/일",
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

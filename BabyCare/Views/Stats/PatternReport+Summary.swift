import SwiftUI
import Charts

extension PatternReportView {
    // MARK: - Summary Section

    func summarySection(_ s: SummaryPattern) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("종합 요약", systemImage: "chart.pie.fill")
                .font(.headline)

            HStack {
                Text("총 기록")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(s.totalRecords)건")
                    .font(.caption.weight(.medium))
            }

            if let most = s.mostActiveDay {
                HStack {
                    Text("가장 활발한 날")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(DateFormatters.shortDate.string(from: most.date)) (\(most.count)건)")
                        .font(.caption.weight(.medium))
                }
            }

            if let least = s.leastActiveDay {
                HStack {
                    Text("가장 적은 날")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(DateFormatters.shortDate.string(from: least.date)) (\(least.count)건)")
                        .font(.caption.weight(.medium))
                }
            }

            if s.missingDays > 2 {
                HStack {
                    Text("기록 누락 \(s.missingDays)일")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }

            // Category distribution donut chart
            if !s.categoryDistribution.isEmpty {
                Text("카테고리 분포")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                let chartData = s.categoryDistribution.map { (category: $0.key, count: $0.value) }
                    .sorted { $0.count > $1.count }

                Chart(chartData, id: \.category) { item in
                    SectorMark(
                        angle: .value("건수", item.count),
                        innerRadius: .ratio(0.5),
                        angularInset: 1.5
                    )
                    .foregroundStyle(by: .value("카테고리", item.category.displayName))
                    .cornerRadius(4)
                }
                .chartForegroundStyleScale([
                    "수유": feedingColor,
                    "수면": sleepColor,
                    "기저귀": diaperColor,
                    "건강": healthColor,
                ])
                .frame(height: 180)
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }
}

import SwiftUI
import Charts

extension PatternReportView {
    // MARK: - Diaper Section

    func diaperSection(_ d: DiaperPattern) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("배변 패턴", systemImage: "humidity.fill")
                .font(.headline)
                .foregroundStyle(diaperColor)

            HStack(spacing: 0) {
                statItem(value: "\(d.totalCount)", label: "총 횟수", unit: "회")
                Divider().frame(height: 30)
                statItem(value: String(format: "%.1f", d.dailyAverage), label: "일평균", unit: "회")
                if d.rashCount > 0 {
                    Divider().frame(height: 30)
                    statItem(value: "\(d.rashCount)", label: "발진", unit: "회")
                }
            }

            // Daily chart
            if !d.dailyCounts.isEmpty {
                Text("일별 추이")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Chart(d.dailyCounts, id: \.date) { item in
                    BarMark(
                        x: .value("날짜", item.date, unit: .day),
                        y: .value("횟수", item.count)
                    )
                    .foregroundStyle(diaperColor.gradient)
                    .cornerRadius(4)
                }
                .chartYAxisLabel("회")
                .frame(height: 160)
            }

            // Wet/Dirty ratio
            HStack {
                Text("유형")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("소변 \(d.wetVsDirtyRatio.wet)")
                    .font(.caption.weight(.medium))
                Text("·").foregroundStyle(.tertiary)
                Text("대변 \(d.wetVsDirtyRatio.dirty)")
                    .font(.caption.weight(.medium))
                Text("·").foregroundStyle(.tertiary)
                Text("혼합 \(d.wetVsDirtyRatio.both)")
                    .font(.caption.weight(.medium))
            }

            // Stool color
            if !d.stoolColorDistribution.isEmpty {
                Text("대변 색")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    ForEach(Array(d.stoolColorDistribution.keys.sorted(by: {
                        d.stoolColorDistribution[$0]! > d.stoolColorDistribution[$1]!
                    })), id: \.self) { color in
                        if let count = d.stoolColorDistribution[color] {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color(hex: color.colorHex))
                                    .frame(width: 10, height: 10)
                                Text("\(color.displayName) \(count)")
                                    .font(.caption2)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(hex: color.colorHex).opacity(0.12))
                            .clipShape(Capsule())
                        }
                    }
                }
            }

            // Consistency
            if !d.consistencyDistribution.isEmpty {
                Text("농도")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    ForEach(Activity.StoolConsistency.allCases, id: \.self) { consistency in
                        if let count = d.consistencyDistribution[consistency] {
                            chipView(
                                icon: consistency.icon,
                                text: "\(consistency.displayName) \(count)",
                                color: diaperColor
                            )
                        }
                    }
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }
}

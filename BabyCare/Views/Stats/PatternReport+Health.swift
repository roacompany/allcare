import SwiftUI
import Charts

extension PatternReportView {
    // MARK: - Health Section

    func healthSection(_ h: HealthPattern) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("건강", systemImage: "heart.text.clipboard.fill")
                .font(.headline)
                .foregroundStyle(healthColor)

            // Temperature chart
            if !h.temperatureReadings.isEmpty {
                if let avg = h.averageTemp {
                    HStack(spacing: 0) {
                        statItem(value: String(format: "%.1f", avg), label: "평균 체온", unit: "°C")
                        Divider().frame(height: 30)
                        statItem(value: "\(h.highTempDays)", label: "발열일", unit: "일")
                    }
                }

                Text("체온 추이")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Chart(h.temperatureReadings, id: \.date) { item in
                    LineMark(
                        x: .value("날짜", item.date),
                        y: .value("체온", item.temp)
                    )
                    .foregroundStyle(healthColor)
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("날짜", item.date),
                        y: .value("체온", item.temp)
                    )
                    .foregroundStyle(item.temp >= 37.5 ? .red : healthColor)

                    RuleMark(y: .value("발열 기준", 37.5))
                        .foregroundStyle(.red.opacity(0.3))
                        .lineStyle(StrokeStyle(dash: [5, 5]))
                }
                .chartYAxisLabel("°C")
                .frame(height: 160)
            }

            // Medications
            HStack {
                Text("투약")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(h.medicationCount)회")
                    .font(.caption.weight(.medium))
            }

            if !h.medicationNames.isEmpty {
                HStack(spacing: 8) {
                    ForEach(Array(h.medicationNames.keys.sorted()), id: \.self) { name in
                        if let count = h.medicationNames[name] {
                            chipView(icon: "pills.fill", text: "\(name) \(count)회", color: healthColor)
                        }
                    }
                }
            }

            if h.temperatureReadings.isEmpty && h.medicationCount == 0 {
                Text("기록된 건강 데이터가 없습니다")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }
}

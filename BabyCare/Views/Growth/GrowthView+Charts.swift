import SwiftUI
import Charts

extension GrowthView {

    // MARK: - Chart Section

    func chartSection(
        title: String,
        icon: String,
        color: Color,
        data: [(Date, Double)],
        metric: GrowthMetric,
        isExpanded: Binding<Bool>
    ) -> some View {
        let baby = babyVM.selectedBaby
        let latestPercentile: Double? = {
            guard let baby, let last = data.last else { return nil }
            let months = ageMonths(from: baby.birthDate, to: last.0)
            return PercentileCalculator.percentile(
                value: last.1,
                ageMonths: months,
                gender: baby.gender,
                metric: metric
            )
        }()

        let velocityResult: GrowthVelocityResult? = {
            guard let baby else { return nil }
            return PercentileCalculator.growthVelocity(
                records: records,
                metric: metric,
                gender: baby.gender,
                birthDate: baby.birthDate
            )
        }()

        return VStack(alignment: .leading, spacing: 12) {
            // Title row with percentile badge
            HStack(alignment: .center, spacing: 8) {
                Label(title, systemImage: icon)
                    .font(.headline)
                    .foregroundStyle(color)

                if let p = latestPercentile {
                    Text("\(percentileLabel(p))")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(.blue.opacity(0.1)))
                        .foregroundStyle(.blue)
                }

                Spacer()
            }

            // Base 180px chart
            Chart(data, id: \.0) { item in
                LineMark(
                    x: .value("날짜", item.0, unit: .day),
                    y: .value("값", item.1)
                )
                .foregroundStyle(color)
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("날짜", item.0, unit: .day),
                    y: .value("값", item.1)
                )
                .foregroundStyle(color)
            }
            .frame(height: 180)

            // Velocity indicator (shown when result is available)
            if let v = velocityResult {
                velocityIndicator(v)
            }

            // Expand button
            if baby != nil {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isExpanded.wrappedValue.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isExpanded.wrappedValue ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                        Text("백분위 차트 \(isExpanded.wrappedValue ? "닫기" : "보기")")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }

                // Expanded percentile chart
                if isExpanded.wrappedValue {
                    expandedChart(data: data, metric: metric, color: color, baby: baby!)
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    // MARK: - Expanded Percentile Chart

    func expandedChart(
        data: [(Date, Double)],
        metric: GrowthMetric,
        color: Color,
        baby: Baby
    ) -> some View {
        let referencePctiles: [Double] = [3, 15, 50, 85, 97]

        // Build reference line points by month 0-24
        // Use baby.birthDate as origin; x-axis = date
        struct RefPoint: Identifiable {
            let id: String
            let date: Date
            let value: Double
            let label: String
        }

        var refLines: [(label: String, points: [RefPoint])] = []
        for p in referencePctiles {
            var pts: [RefPoint] = []
            for month in 0...24 {
                let date = Calendar.current.date(
                    byAdding: .month, value: month, to: baby.birthDate
                ) ?? baby.birthDate
                if let val = PercentileCalculator.referenceValue(
                    percentile: p,
                    ageMonths: month,
                    gender: baby.gender,
                    metric: metric
                ) {
                    pts.append(RefPoint(id: "\(Int(p))th-\(month)", date: date, value: val, label: "\(Int(p))th"))
                }
            }
            refLines.append((label: "\(Int(p))th", points: pts))
        }

        return VStack(alignment: .leading, spacing: 6) {
            Chart {
                // WHO reference lines
                ForEach(Array(refLines.enumerated()), id: \.offset) { _, line in
                    ForEach(line.points) { pt in
                        LineMark(
                            x: .value("날짜", pt.date, unit: .month),
                            y: .value(line.label, pt.value),
                            series: .value("계열", line.label)
                        )
                        .foregroundStyle(
                            line.label == "50th"
                                ? Color.secondary.opacity(0.5)
                                : Color.secondary.opacity(0.3)
                        )
                        .lineStyle(StrokeStyle(dash: [4, 4]))
                    }
                }

                // Child data
                ForEach(data, id: \.0) { item in
                    LineMark(
                        x: .value("날짜", item.0, unit: .day),
                        y: .value("값", item.1),
                        series: .value("계열", "아이")
                    )
                    .foregroundStyle(color)
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("날짜", item.0, unit: .day),
                        y: .value("값", item.1)
                    )
                    .foregroundStyle(color)
                }
            }
            .frame(height: 280)

            // Reference line legend
            HStack(spacing: 12) {
                ForEach(referencePctiles, id: \.self) { p in
                    Text("\(Int(p))th")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("WHO 2006")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            // Disclaimer
            Text("이 성장 기록은 참고용이며 의학적 진단을 대체하지 않습니다.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

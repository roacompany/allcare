import SwiftUI
import Charts

// MARK: - Private structs

private struct BandPoint: Identifiable {
    let id: String
    let ageMonths: Int
    let low: Double
    let high: Double
}

private struct GrowthTrendPoint: Identifiable {
    let id: String
    let date: Date
    let percentile: Double
}

private struct WHOBands {
    var band3_15: [BandPoint] = []
    var band15_50: [BandPoint] = []
    var band50_85: [BandPoint] = []
    var band85_97: [BandPoint] = []
    var median50: [(ageMonths: Int, value: Double)] = []
}

extension GrowthView {

    // MARK: - WHO Band Builder

    private func buildWHOBands(baby: Baby, metric: GrowthMetric) -> WHOBands {
        var bands = WHOBands()
        for month in 0...24 {
            let g = baby.gender
            guard
                let v3  = PercentileCalculator.referenceValue(percentile: 3,  ageMonths: month, gender: g, metric: metric),
                let v15 = PercentileCalculator.referenceValue(percentile: 15, ageMonths: month, gender: g, metric: metric),
                let v50 = PercentileCalculator.referenceValue(percentile: 50, ageMonths: month, gender: g, metric: metric),
                let v85 = PercentileCalculator.referenceValue(percentile: 85, ageMonths: month, gender: g, metric: metric),
                let v97 = PercentileCalculator.referenceValue(percentile: 97, ageMonths: month, gender: g, metric: metric)
            else { continue }

            bands.band3_15.append(BandPoint(id: "3-15-\(month)",   ageMonths: month, low: v3,  high: v15))
            bands.band15_50.append(BandPoint(id: "15-50-\(month)", ageMonths: month, low: v15, high: v50))
            bands.band50_85.append(BandPoint(id: "50-85-\(month)", ageMonths: month, low: v50, high: v85))
            bands.band85_97.append(BandPoint(id: "85-97-\(month)", ageMonths: month, low: v85, high: v97))
            bands.median50.append((ageMonths: month, value: v50))
        }
        return bands
    }

    // MARK: - Chart Section

    func chartSection(
        title: String,
        icon: String,
        color: Color,
        data: [(Date, Double)],
        metric: GrowthMetric
    ) -> some View {
        let baby = babyVM.selectedBaby
        let latestPercentile: Double? = {
            guard let baby, let last = data.last else { return nil }
            let months = ageMonths(from: baby.birthDate, to: last.0)
            return PercentileCalculator.percentile(
                value: last.1, ageMonths: months, gender: baby.gender, metric: metric
            )
        }()
        let velocityResult: GrowthVelocityResult? = {
            guard let baby else { return nil }
            return PercentileCalculator.growthVelocity(
                records: records, metric: metric, gender: baby.gender, birthDate: baby.birthDate
            )
        }()
        let bands: WHOBands = baby.map { buildWHOBands(baby: $0, metric: metric) } ?? WHOBands()
        let babyPoints: [(ageMonths: Int, value: Double)] = {
            guard let baby else { return [] }
            return data.map { (date, val) in (ageMonths: ageMonths(from: baby.birthDate, to: date), value: val) }
        }()

        return VStack(alignment: .leading, spacing: 12) {
            percentileBadgeRow(title: title, icon: icon, color: color, latestPercentile: latestPercentile)
            whoBandChart(bands: bands, babyPoints: babyPoints, color: color)
                .frame(height: 240)
            if let v = velocityResult { velocityIndicator(v) }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    // MARK: - Subviews

    @ViewBuilder
    private func percentileBadgeRow(title: String, icon: String, color: Color, latestPercentile: Double?) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(color)
            if let p = latestPercentile {
                let topPercent = max(1, Int(round(100 - p)))
                let badgeColor: Color = p < 15 ? .red : p > 85 ? .blue : .green
                Text("또래 상위 \(topPercent)%")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(badgeColor.opacity(0.1)))
                    .foregroundStyle(badgeColor)
            }
            Spacer()
        }
    }

    private func whoBandChart(
        bands: WHOBands,
        babyPoints: [(ageMonths: Int, value: Double)],
        color: Color
    ) -> some View {
        Chart {
            ForEach(bands.band3_15) { pt in
                AreaMark(x: .value("월령", pt.ageMonths), yStart: .value("낮음", pt.low), yEnd: .value("높음", pt.high), series: .value("계열", "3-15"))
                    .foregroundStyle(Color.red.opacity(0.08))
            }
            ForEach(bands.band15_50) { pt in
                AreaMark(x: .value("월령", pt.ageMonths), yStart: .value("낮음", pt.low), yEnd: .value("높음", pt.high), series: .value("계열", "15-50"))
                    .foregroundStyle(Color.yellow.opacity(0.08))
            }
            ForEach(bands.band50_85) { pt in
                AreaMark(x: .value("월령", pt.ageMonths), yStart: .value("낮음", pt.low), yEnd: .value("높음", pt.high), series: .value("계열", "50-85"))
                    .foregroundStyle(Color.green.opacity(0.08))
            }
            ForEach(bands.band85_97) { pt in
                AreaMark(x: .value("월령", pt.ageMonths), yStart: .value("낮음", pt.low), yEnd: .value("높음", pt.high), series: .value("계열", "85-97"))
                    .foregroundStyle(Color.yellow.opacity(0.08))
            }
            ForEach(bands.median50, id: \.ageMonths) { pt in
                LineMark(x: .value("월령", pt.ageMonths), y: .value("중앙값", pt.value), series: .value("계열", "50th"))
                    .foregroundStyle(Color.gray.opacity(0.5))
                    .lineStyle(StrokeStyle(dash: [4, 4]))
            }
            ForEach(babyPoints, id: \.ageMonths) { pt in
                LineMark(x: .value("월령", pt.ageMonths), y: .value("값", pt.value), series: .value("계열", "아이"))
                    .foregroundStyle(color)
                    .interpolationMethod(.catmullRom)
                PointMark(x: .value("월령", pt.ageMonths), y: .value("값", pt.value))
                    .foregroundStyle(color)
            }
        }
    }

    // MARK: - Percentile Trend Chart

    @ViewBuilder
    func percentileTrendChart(
        records: [GrowthRecord],
        metric: GrowthMetric,
        gender: Baby.Gender,
        birthDate: Date
    ) -> some View {
        let points: [GrowthTrendPoint] = records.compactMap { record in
            let value: Double?
            switch metric {
            case .weight:            value = record.weight
            case .height:            value = record.height
            case .headCircumference: value = record.headCircumference
            }
            guard let v = value else { return nil }
            let months = ageMonths(from: birthDate, to: record.date)
            guard let pct = PercentileCalculator.percentile(
                value: v, ageMonths: months, gender: gender, metric: metric
            ) else { return nil }
            return GrowthTrendPoint(id: record.id, date: record.date, percentile: pct)
        }

        VStack(alignment: .leading, spacing: 4) {
            Text("백분위 추이")
                .font(.caption)
                .foregroundStyle(.secondary)
            if points.count >= 3 {
                Chart {
                    RuleMark(y: .value("50th", 50))
                        .lineStyle(StrokeStyle(dash: [4, 4]))
                        .foregroundStyle(.secondary.opacity(0.5))
                    ForEach(points) { pt in
                        LineMark(x: .value("날짜", pt.date, unit: .day), y: .value("백분위", pt.percentile))
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(.blue)
                        PointMark(x: .value("날짜", pt.date, unit: .day), y: .value("백분위", pt.percentile))
                            .foregroundStyle(.blue)
                    }
                }
                .chartYScale(domain: 0...100)
                .frame(height: 120)
            } else {
                Text("측정 기록이 3개 이상이면 백분위 추이를 볼 수 있어요")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

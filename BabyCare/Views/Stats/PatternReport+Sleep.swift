import SwiftUI
import Charts

extension PatternReportView {
    // MARK: - Sleep Section

    func sleepSection(_ s: SleepPattern) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(NSLocalizedString("sleep.section.title", comment: ""), systemImage: "moon.zzz.fill")
                .font(.headline)
                .foregroundStyle(sleepColor)
            sleepSummaryStats(s)
            sleepDistributionRows(s)
            if vm.showComparison {
                comparisonRow(
                    current: s.dailyAverageHours,
                    previous: s.previousDailyAverageHours,
                    unit: NSLocalizedString("sleep.comparison.unit", comment: ""),
                    label: NSLocalizedString("sleep.comparison.label", comment: "")
                )
            }
            if let warning = s.regressionWarning { sleepRegressionCard(warning) }
            if let bedtime = s.optimalBedtime { optimalBedtimeCard(bedtime) }
            if let ratios = s.napNightRatios, !ratios.isEmpty { napNightRatioChart(ratios) }
            if let score = s.qualityScore { sleepQualityScoreCard(score) }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    @ViewBuilder
    private func sleepSummaryStats(_ s: SleepPattern) -> some View {
        HStack(spacing: 0) {
            statItem(
                value: String(format: "%.1f", s.dailyAverageHours),
                label: NSLocalizedString("sleep.stat.dailyAvg", comment: ""),
                unit: NSLocalizedString("sleep.unit.hours", comment: "")
            )
            Divider().frame(height: 30)
            statItem(value: s.averageDuration.shortDuration, label: NSLocalizedString("sleep.stat.sessionAvg", comment: ""), unit: "")
            Divider().frame(height: 30)
            statItem(value: s.durationTrend.rawValue, label: NSLocalizedString("sleep.stat.trend", comment: ""), unit: "")
        }
        if !s.dailyHours.isEmpty {
            Text(NSLocalizedString("sleep.chart.daily", comment: ""))
                .font(.caption).foregroundStyle(.secondary)
            Chart(s.dailyHours, id: \.date) { item in
                BarMark(x: .value("날짜", item.date, unit: .day), y: .value("시간", item.hours))
                    .foregroundStyle(sleepColor.gradient)
                    .cornerRadius(4)
            }
            .chartYAxisLabel(NSLocalizedString("sleep.unit.hours", comment: ""))
            .frame(height: 160)
        }
    }

    @ViewBuilder
    private func sleepDistributionRows(_ s: SleepPattern) -> some View {
        if !s.qualityDistribution.isEmpty {
            Text(NSLocalizedString("sleep.quality.title", comment: ""))
                .font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 8) {
                ForEach(Activity.SleepQualityType.allCases, id: \.self) { quality in
                    if let count = s.qualityDistribution[quality] {
                        chipView(icon: quality.icon, text: "\(quality.displayName) \(count)", color: sleepColor)
                    }
                }
            }
        }
        if !s.methodDistribution.isEmpty {
            Text(NSLocalizedString("sleep.method.title", comment: ""))
                .font(.caption).foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Activity.SleepMethodType.allCases, id: \.self) { method in
                        if let count = s.methodDistribution[method] {
                            chipView(icon: method.icon, text: "\(method.displayName) \(count)", color: sleepColor)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Regression Warning Card

    @ViewBuilder
    func sleepRegressionCard(_ warning: SleepRegressionWarning) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(NSLocalizedString("sleep.regression.card.title", comment: ""))
                    .font(.subheadline.bold())
                    .foregroundStyle(.orange)
            }

            if let recent = warning.recentAvgHours, let baseline = warning.baselineAvgHours {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(NSLocalizedString("sleep.regression.recent7", comment: ""))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.1f%@", recent, NSLocalizedString("sleep.unit.hours", comment: "")))
                            .font(.subheadline.bold())
                    }
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(NSLocalizedString("sleep.regression.baseline", comment: ""))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.1f%@", baseline, NSLocalizedString("sleep.unit.hours", comment: "")))
                            .font(.subheadline.bold())
                    }
                }
            }

            if let rate = warning.declineRate {
                Text(String(format: NSLocalizedString("sleep.regression.decline", comment: ""), Int(abs(rate * 100))))
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            Text(NSLocalizedString("sleep.regression.disclaimer", comment: ""))
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(Color.orange.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Optimal Bedtime Card

    @ViewBuilder
    func optimalBedtimeCard(_ bedtime: OptimalBedtime) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(
                NSLocalizedString("sleep.bedtime.card.title", comment: ""),
                systemImage: "moon.stars.fill"
            )
            .font(.subheadline.bold())
            .foregroundStyle(sleepColor)

            if let start = bedtime.bedtimeStart, let end = bedtime.bedtimeEnd {
                HStack {
                    Image(systemName: "clock.fill")
                        .foregroundStyle(sleepColor)
                    Text(String(
                        format: NSLocalizedString("sleep.bedtime.window", comment: ""),
                        SleepAnalysisService.formatBedtimeSeconds(start),
                        SleepAnalysisService.formatBedtimeSeconds(end)
                    ))
                    .font(.subheadline)
                }
            }

            if let count = bedtime.sampleCount {
                Text(String(format: NSLocalizedString("sleep.bedtime.sampleCount", comment: ""), count))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(sleepColor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Nap vs Night Ratio Chart

    @ViewBuilder
    func napNightRatioChart(_ ratios: [NapNightRatio]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(
                NSLocalizedString("sleep.napnight.title", comment: ""),
                systemImage: "sun.and.horizon.fill"
            )
            .font(.subheadline.bold())
            .foregroundStyle(sleepColor)

            let validRatios = ratios.compactMap { ratio -> (date: Date, napHours: Double, nightHours: Double)? in
                guard let date = ratio.date,
                      let nap = ratio.napHours,
                      let night = ratio.nightHours else { return nil }
                return (date: date, napHours: nap, nightHours: night)
            }

            if !validRatios.isEmpty {
                Chart {
                    ForEach(validRatios, id: \.date) { item in
                        BarMark(
                            x: .value("날짜", item.date, unit: .day),
                            y: .value(NSLocalizedString("sleep.napnight.nap", comment: ""), item.napHours)
                        )
                        .foregroundStyle(Color.yellow.opacity(0.7))
                        .cornerRadius(3)

                        BarMark(
                            x: .value("날짜", item.date, unit: .day),
                            y: .value(NSLocalizedString("sleep.napnight.night", comment: ""), item.nightHours)
                        )
                        .foregroundStyle(sleepColor.opacity(0.7))
                        .cornerRadius(3)
                    }
                }
                .chartForegroundStyleScale([
                    NSLocalizedString("sleep.napnight.nap", comment: ""): Color.yellow.opacity(0.7),
                    NSLocalizedString("sleep.napnight.night", comment: ""): sleepColor.opacity(0.7)
                ])
                .chartYAxisLabel(NSLocalizedString("sleep.unit.hours", comment: ""))
                .frame(height: 140)
            }
        }
        .padding(12)
        .background(sleepColor.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Sleep Quality Score Card

    @ViewBuilder
    func sleepQualityScoreCard(_ qs: SleepQualityScore) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(
                NSLocalizedString("sleep.score.title", comment: ""),
                systemImage: "star.circle.fill"
            )
            .font(.subheadline.bold())
            .foregroundStyle(sleepColor)

            if let score = qs.score {
                HStack(alignment: .center, spacing: 12) {
                    // Score circle
                    ZStack {
                        Circle()
                            .stroke(sleepColor.opacity(0.2), lineWidth: 6)
                        Circle()
                            .trim(from: 0, to: CGFloat(score) / 100)
                            .stroke(scoreColor(score), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Text("\(score)")
                            .font(.title3.bold())
                            .foregroundStyle(scoreColor(score))
                    }
                    .frame(width: 60, height: 60)

                    VStack(alignment: .leading, spacing: 4) {
                        if let dur = qs.durationScore {
                            scoreRow(
                                icon: "clock.fill",
                                label: NSLocalizedString("sleep.score.duration", comment: ""),
                                value: dur,
                                max: 50
                            )
                        }
                        if let wake = qs.wakeScore {
                            scoreRow(
                                icon: "moon.zzz.fill",
                                label: NSLocalizedString("sleep.score.wake", comment: ""),
                                value: wake,
                                max: 30
                            )
                        }
                        if let nap = qs.napScore {
                            scoreRow(
                                icon: "sun.max.fill",
                                label: NSLocalizedString("sleep.score.nap", comment: ""),
                                value: nap,
                                max: 20
                            )
                        }
                    }
                    Spacer()
                }
            }

            Text(NSLocalizedString("sleep.score.disclaimer", comment: ""))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(sleepColor.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Score Helpers

    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 80...: return .green
        case 60..<80: return sleepColor
        case 40..<60: return .orange
        default: return .red
        }
    }

    @ViewBuilder
    private func scoreRow(icon: String, label: String, value: Int, max: Int) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(sleepColor)
                .frame(width: 14)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(value)/\(max)")
                .font(.caption2.bold())
        }
    }
}

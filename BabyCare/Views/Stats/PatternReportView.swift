import SwiftUI
import Charts

struct PatternReportView: View {
    @Environment(PatternReportViewModel.self) private var vm
    @Environment(BabyViewModel.self) private var babyVM
    @Environment(AuthViewModel.self) private var authVM

    private let feedingColor = Color(hex: "FF9FB5")
    private let sleepColor = Color(hex: "9FB5FF")
    private let diaperColor = Color(hex: "FFD59F")
    private let healthColor = Color(hex: "9FDFBF")

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                periodPicker

                if vm.isLoading {
                    ProgressView()
                        .padding(60)
                } else if let report = vm.report {
                    if report.summary.totalRecords == 0 {
                        emptyStateView
                    } else {
                        aiInsightCard
                        feedingSection(report.feeding)
                        sleepSection(report.sleep)
                        diaperSection(report.diaper)
                        healthSection(report.health)
                        summarySection(report.summary)
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("패턴 분석")
        .task { await loadReport() }
        .onChange(of: vm.selectedPeriod) {
            Task { await loadReport() }
        }
    }

    // MARK: - Period Picker

    private var periodPicker: some View {
        Picker("기간", selection: Bindable(vm).selectedPeriod) {
            ForEach(PatternReportViewModel.Period.allCases, id: \.self) { period in
                Text(period.rawValue).tag(period)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text("분석할 데이터가 없습니다")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("활동을 기록하면 패턴을 분석해드려요")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - AI Insight Card

    private var aiInsightCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "brain.head.profile.fill")
                    .foregroundStyle(.purple)
                Text("AI 패턴 분석")
                    .font(.headline)
                Spacer()
            }

            if let insight = vm.aiInsight {
                Text(insight)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineSpacing(4)
            } else if vm.isLoadingAI {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("분석 중...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                if vm.hasAPIKey {
                    Button {
                        Task { await requestAI() }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                            Text("AI 분석 받기")
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.purple.gradient, in: Capsule())
                    }
                } else {
                    Text("설정에서 AI API 키를 입력하면 맞춤 분석을 받을 수 있어요")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let error = vm.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding()
        .background(Color.purple.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    // MARK: - Feeding Section

    private func feedingSection(_ f: FeedingPattern) -> some View {
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
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    // MARK: - Sleep Section

    private func sleepSection(_ s: SleepPattern) -> some View {
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
                Text("잠드는 방법")
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
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    // MARK: - Diaper Section

    private func diaperSection(_ d: DiaperPattern) -> some View {
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

    // MARK: - Health Section

    private func healthSection(_ h: HealthPattern) -> some View {
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

    // MARK: - Summary Section

    private func summarySection(_ s: SummaryPattern) -> some View {
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

    // MARK: - Helpers

    private func statItem(value: String, label: String, unit: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 2) {
                Text(value)
                    .font(.title3.bold())
                if !unit.isEmpty {
                    Text(unit)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func trendBadge(_ trend: Trend) -> some View {
        HStack(spacing: 2) {
            Image(systemName: trend == .increasing ? "arrow.up.right" :
                    trend == .decreasing ? "arrow.down.right" : "arrow.right")
                .font(.caption2)
            Text(trend.rawValue)
                .font(.caption)
        }
        .foregroundStyle(trend == .increasing ? .orange :
                            trend == .decreasing ? .blue : .secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            (trend == .increasing ? Color.orange :
                trend == .decreasing ? Color.blue : Color.secondary).opacity(0.12)
        )
        .clipShape(Capsule())
    }

    private func chipView(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(.caption2)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }

    // MARK: - Actions

    private func loadReport() async {
        guard let userId = authVM.currentUserId,
              let babyId = babyVM.selectedBaby?.id else { return }
        await vm.loadReport(userId: userId, babyId: babyId)
    }

    private func requestAI() async {
        guard let baby = babyVM.selectedBaby else { return }
        await vm.requestAIInsight(
            babyName: baby.name,
            babyAge: baby.ageText,
            gender: baby.gender.displayName
        )
    }
}

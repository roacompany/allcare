import SwiftUI
import Charts

struct PregnancyWeightView: View {
    @Environment(PregnancyViewModel.self) private var pregnancyVM
    @Environment(AuthViewModel.self) private var authVM

    @State private var showAddSheet = false
    @State private var showBaselineSheet = false

    private var sortedEntries: [PregnancyWeightEntry] {
        pregnancyVM.weightEntries.sorted(by: { $0.measuredAt < $1.measuredAt })
    }

    private var prePregnancyWeight: Double? {
        pregnancyVM.activePregnancy?.prePregnancyWeight
    }

    private var prePregnancyHeight: Double? {
        pregnancyVM.activePregnancy?.prePregnancyHeight
    }

    private var fetusCount: Int {
        pregnancyVM.activePregnancy?.fetusCount ?? 1
    }

    private var weightUnit: String {
        pregnancyVM.activePregnancy?.weightUnit ?? "kg"
    }

    /// 현재 임신 주차 (LMP 기준).
    private var currentWeek: Int? {
        PregnancyDateMath.weekAndDay(from: pregnancyVM.activePregnancy?.lmpDate, now: Date())?.weeks
    }

    /// 가장 최근 기록 체중.
    private var latestWeight: Double? {
        sortedEntries.last?.weight
    }

    /// BMI 권장 증가밴드 표시 상태 (가드 통과 시에만 non-nil).
    private var bandGuidance: KoreanGestationalWeightGain.Guidance? {
        KoreanGestationalWeightGain.guidance(
            prePregnancyHeightCm: prePregnancyHeight,
            prePregnancyWeightKg: prePregnancyWeight,
            latestWeightKg: latestWeight,
            currentWeek: currentWeek,
            fetusCount: fetusCount
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 면책 배너
                HStack(spacing: 10) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(.orange)
                    Text("체중 변화는 참고용 기록입니다. 의학적 판단은 담당 의료진에게 문의하세요.")
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(.orange.opacity(0.4), lineWidth: 1))

                if sortedEntries.isEmpty {
                    ContentUnavailableView(
                        "체중 기록 없음",
                        systemImage: "scalemass",
                        description: Text("체중을 기록해보세요.")
                    )
                    .frame(height: 200)
                } else {
                    weightChartCard
                }

                weightGainBandSection

                weightEntriesSection
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .navigationTitle("체중 추이")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            WeightEntryFormSheet()
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showBaselineSheet) {
            PrePregnancyBaselineSheet(height: prePregnancyHeight, weight: prePregnancyWeight)
                .presentationDetents([.medium])
        }
    }

    // MARK: - Chart Card

    private var weightChartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("체중 변화")
                .font(.headline)

            Chart {
                ForEach(sortedEntries) { entry in
                    LineMark(
                        x: .value("날짜", entry.measuredAt),
                        y: .value("체중", entry.weight)
                    )
                    .foregroundStyle(AppColors.sageColor)

                    PointMark(
                        x: .value("날짜", entry.measuredAt),
                        y: .value("체중", entry.weight)
                    )
                    .foregroundStyle(AppColors.sageColor)
                }

                if let baseWeight = prePregnancyWeight {
                    RuleMark(y: .value("임신 전 체중", baseWeight))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [6, 3]))
                        .foregroundStyle(.secondary.opacity(0.6))
                        .annotation(position: .trailing, alignment: .center) {
                            Text("임신 전")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                }
            }
            .chartYAxisLabel("\(weightUnit)")
            .chartXAxis {
                AxisMarks(values: .stride(by: .month)) { _ in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                }
            }
            .frame(height: 200)

            if let baseWeight = prePregnancyWeight,
               let lastEntry = sortedEntries.last {
                let diff = lastEntry.weight - baseWeight
                let sign = diff >= 0 ? "+" : ""
                HStack {
                    Text("임신 전 대비:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(sign)\(String(format: "%.1f", diff))\(weightUnit)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(diff >= 0 ? AppColors.sageColor : .secondary)
                }
            }
        }
        .padding(16)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - 권장 증가 밴드 (임신 전 BMI 기준)

    @ViewBuilder
    private var weightGainBandSection: some View {
        if fetusCount > 1 {
            twinBandNote
        } else if prePregnancyHeight == nil || prePregnancyWeight == nil {
            baselinePromptCard
        } else if let guidance = bandGuidance {
            weightGainBandCard(guidance)
        }
        // 단태아·기준 입력 완료이나 체중/주차 부족 → 차트 빈상태가 안내(별도 표시 없음)
    }

    /// 주차별 권장 누적 증가 밴드 시리즈 (0~40주).
    private func bandSeries(for category: KoreanGestationalWeightGain.Category) -> [(week: Int, lower: Double, upper: Double)] {
        stride(from: 0, through: 40, by: 1).compactMap { w in
            guard let r = KoreanGestationalWeightGain.recommendedCumulativeRange(atWeek: w, category: category) else { return nil }
            return (w, r.lowerBound, r.upperBound)
        }
    }

    /// 내 체중 기록의 누적 증가량 시리즈 (주차 매핑).
    private var gainSeries: [(week: Int, gain: Double)] {
        guard let base = prePregnancyWeight, let lmp = pregnancyVM.activePregnancy?.lmpDate else { return [] }
        return sortedEntries.compactMap { entry in
            guard let wk = PregnancyDateMath.weekAndDay(from: lmp, now: entry.measuredAt)?.weeks, wk >= 0 else { return nil }
            return (wk, entry.weight - base)
        }
    }

    private func weightGainBandCard(_ guidance: KoreanGestationalWeightGain.Guidance) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("권장 증가 밴드")
                    .font(.headline)
                Spacer()
                Button("기준 수정") { showBaselineSheet = true }
                    .font(.caption)
                    .tint(DS2.Color.pregnancy)
            }

            if let h = prePregnancyHeight, let w = prePregnancyWeight,
               let bmi = KoreanGestationalWeightGain.bmi(heightCm: h, weightKg: w) {
                Text("임신 전 BMI \(String(format: "%.1f", bmi)) · \(guidance.category.displayName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Chart {
                ForEach(bandSeries(for: guidance.category), id: \.week) { p in
                    AreaMark(
                        x: .value("주차", p.week),
                        yStart: .value("하한", p.lower),
                        yEnd: .value("상한", p.upper)
                    )
                    .foregroundStyle(DS2.Color.pregnancy.opacity(0.15))
                    .interpolationMethod(.monotone)
                }
                ForEach(Array(gainSeries.enumerated()), id: \.offset) { _, p in
                    LineMark(
                        x: .value("주차", p.week),
                        y: .value("누적 증가", p.gain),
                        series: .value("series", "me")
                    )
                    .foregroundStyle(DS2.Color.pregnancy)
                    PointMark(
                        x: .value("주차", p.week),
                        y: .value("누적 증가", p.gain)
                    )
                    .foregroundStyle(DS2.Color.pregnancy)
                }
                if let wk = currentWeek {
                    RuleMark(x: .value("현재", wk))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .foregroundStyle(.secondary.opacity(0.5))
                }
            }
            .chartXScale(domain: 0...40)
            .chartXAxisLabel("주차")
            .chartYAxisLabel("\(weightUnit) 증가")
            .frame(height: 200)

            HStack {
                Text("현재 \(guidance.week)주 · 누적 \(guidance.cumulativeGainKg >= 0 ? "+" : "")\(String(format: "%.1f", guidance.cumulativeGainKg))\(weightUnit)")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(positionText(guidance.position))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(DS2.Color.pregnancy)
            }

            Text("권장 밴드는 대한산부인과학회 기준의 참고 정보예요. 초기엔 천천히 늘거나 입덧으로 정체·감소할 수 있고 개인차가 있어요. 의학적 판단은 담당 의료진과 상의하세요.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    /// 밴드 위치 문구 — 경고 톤 금지(중립 위치 안내만).
    private func positionText(_ position: KoreanGestationalWeightGain.BandPosition) -> String {
        switch position {
        case .within: return "권장 범위 안이에요"
        case .below:  return "권장보다 천천히 늘고 있어요"
        case .above:  return "권장보다 빠르게 늘고 있어요"
        }
    }

    private var baselinePromptCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("권장 증가 밴드")
                .font(.headline)
            Text("임신 전 키와 체중을 입력하면, 임신 전 BMI에 맞는 권장 증가 범위 위에 내 체중 추이를 겹쳐 볼 수 있어요.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button {
                showBaselineSheet = true
            } label: {
                Label("기준 정보 입력", systemImage: "ruler")
            }
            .buttonStyle(.borderedProminent)
            .tint(DS2.Color.pregnancy)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var twinBandNote: some View {
        HStack(spacing: 10) {
            Image(systemName: "info.circle")
                .foregroundStyle(DS2.Color.pregnancy)
            Text("다태아는 권장 증가 범위가 단태아와 달라요. 담당 의료진과 상의하세요.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS2.Color.pregnancy.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Entries Section

    private var weightEntriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("기록 목록")
                .font(.headline)
                .padding(.horizontal, 4)

            ForEach(sortedEntries.reversed().prefix(20)) { entry in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.measuredAt, style: .date)
                            .font(.subheadline.weight(.medium))
                        if let notes = entry.notes {
                            Text(notes)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    Text("\(String(format: "%.1f", entry.weight)) \(entry.unit)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColors.sageColor)
                }
                .padding(12)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}

// MARK: - Weight Entry Form Sheet

private struct WeightEntryFormSheet: View {
    @Environment(PregnancyViewModel.self) private var pregnancyVM
    @Environment(AuthViewModel.self) private var authVM
    @Environment(\.dismiss) private var dismiss

    @State private var weight: String = ""
    @State private var unit: String = "kg"
    @State private var measuredAt: Date = Date()
    @State private var notes: String = ""
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("체중") {
                    HStack {
                        TextField("체중 입력", text: $weight)
                            .keyboardType(.decimalPad)
                        Picker("단위", selection: $unit) {
                            Text("kg").tag("kg")
                            Text("lb").tag("lb")
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 100)
                    }

                    DatePicker("측정 날짜", selection: $measuredAt, displayedComponents: .date)
                        .environment(\.locale, Locale(identifier: "ko_KR"))
                }

                Section("메모") {
                    TextField("메모 (선택)", text: $notes)
                }
            }
            .navigationTitle("체중 기록")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        Task { await save() }
                    }
                    .disabled(isSaving || weight.isEmpty)
                }
            }
        }
    }

    private func save() async {
        guard let userId = authVM.currentUserId,
              let pid = pregnancyVM.activePregnancy?.id,
              let weightValue = Double(weight) else { return }
        isSaving = true
        defer { isSaving = false }

        let entry = PregnancyWeightEntry(
            pregnancyId: pid,
            weight: weightValue,
            unit: unit,
            measuredAt: measuredAt,
            notes: notes.isEmpty ? nil : notes
        )
        await pregnancyVM.addWeightEntry(entry, userId: userId)
        if pregnancyVM.errorMessage == nil {
            dismiss()
        }
    }
}

// MARK: - Pre-pregnancy Baseline Sheet (임신 전 키·체중)

/// 임신 전 키·체중 1회 입력 — BMI 권장 증가밴드 기준점. kg·cm 단위 고정(FEATURES §③).
private struct PrePregnancyBaselineSheet: View {
    @Environment(PregnancyViewModel.self) private var pregnancyVM
    @Environment(AuthViewModel.self) private var authVM
    @Environment(\.dismiss) private var dismiss

    @State private var height: String
    @State private var weight: String
    @State private var isSaving = false

    init(height: Double?, weight: Double?) {
        _height = State(initialValue: height.map { String(format: "%.0f", $0) } ?? "")
        _weight = State(initialValue: weight.map { String(format: "%.1f", $0) } ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("키")
                        Spacer()
                        TextField("0", text: $height)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("cm").foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("임신 전 체중")
                        Spacer()
                        TextField("0", text: $weight)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("kg").foregroundStyle(.secondary)
                    }
                } header: {
                    Text("임신 전 기준 정보")
                } footer: {
                    Text("임신 전 BMI를 계산해 권장 증가 범위를 안내하는 데만 쓰여요. 의학적 판단이 아니에요.")
                }
            }
            .navigationTitle("기준 정보")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        Task { await save() }
                    }
                    .disabled(isSaving)
                }
            }
        }
    }

    private func save() async {
        guard let userId = authVM.currentUserId else { return }
        isSaving = true
        defer { isSaving = false }
        // 빈 입력 → nil(해당 값 제거). 둘 다 채워야 밴드 표시.
        await pregnancyVM.setPrePregnancyBaseline(
            heightCm: Double(height),
            weightKg: Double(weight),
            userId: userId
        )
        if pregnancyVM.errorMessage == nil {
            dismiss()
        }
    }
}

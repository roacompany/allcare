import SwiftUI
import Charts

/// 혈압/혈당 추적 (②기록 [상태별]). 최근 값 + 혈당 추이(임당 참고 목표선 비교) + 입력.
/// 참고용 — "정상/위험" 의학 단정 텍스트 금지. 점 색 = 맥락별 참고선 이내/초과.
@MainActor
struct PregnancyVitalsView: View {
    @Environment(PregnancyViewModel.self) private var pregnancyVM
    @State private var showInput = false

    private var entries: [PregnancyVitalEntry] { pregnancyVM.vitalEntries }
    private var glucoseEntries: [PregnancyVitalEntry] {
        entries.filter { $0.glucose != nil }.sorted { $0.measuredAt < $1.measuredAt }
    }
    private var latestBP: PregnancyVitalEntry? {
        entries.first { $0.systolic != nil && $0.diastolic != nil }
    }
    private var latestGlucose: PregnancyVitalEntry? {
        entries.first { $0.glucose != nil }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: DS2.Spacing.lg) {
                disclaimer

                if entries.isEmpty {
                    ContentUnavailableView("기록 없음", systemImage: "heart.text.square",
                                           description: Text("혈압·혈당을 기록하면 추이를 볼 수 있어요."))
                        .padding(.top, DS2.Spacing.xl)
                } else {
                    recentSummary
                    if !glucoseEntries.isEmpty { glucoseChart }
                }
            }
            .padding(DS2.Spacing.lg)
        }
        .navigationTitle("혈압 / 혈당")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showInput = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showInput) { PregnancyVitalEntrySheet() }
    }

    // MARK: - 면책

    private var disclaimer: some View {
        HStack(spacing: DS2.Spacing.sm) {
            Image(systemName: "info.circle.fill").foregroundStyle(DS2.Color.warning)
            Text("수치는 참고용이에요. 의학적 판단은 담당 의료진과 함께 하세요.")
                .font(DS2.Font.caption).foregroundStyle(DS2.Color.textPrimary)
            Spacer(minLength: 0)
        }
        .padding(DS2.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS2.Color.warning.opacity(0.12), in: RoundedRectangle(cornerRadius: DS2.Radius.sm))
    }

    // MARK: - 최근 값

    private var recentSummary: some View {
        HStack(spacing: DS2.Spacing.md) {
            if let bp = latestBP, let sys = bp.systolic, let dia = bp.diastolic {
                summaryCell(title: "혈압", value: "\(sys)/\(dia)", unit: "mmHg", within: nil)
            }
            if let g = latestGlucose, let value = g.glucose {
                let ctx = g.glucoseContext.flatMap(PregnancyVitalEntry.GlucoseContext.init(rawValue:))
                let within = ctx.map { PregnancyVitalEntry.glucoseWithinReference(value: value, context: $0) }
                summaryCell(title: "혈당 \(ctx?.displayName ?? "")", value: "\(value)", unit: "mg/dL", within: within)
            }
            Spacer(minLength: 0)
        }
    }

    private func summaryCell(title: String, value: String, unit: String, within: Bool?) -> some View {
        DS2Card {
            VStack(alignment: .leading, spacing: DS2.Spacing.xs) {
                Text(title).font(DS2.Font.caption).foregroundStyle(DS2.Color.textSecondary)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(value).font(DS2.Font.title3).foregroundStyle(referenceColor(within))
                    Text(unit).font(DS2.Font.caption2).foregroundStyle(DS2.Color.textSecondary)
                }
                if let within {
                    Label(within ? "참고선 이내" : "참고선 초과",
                          systemImage: within ? "checkmark.circle" : "exclamationmark.circle")
                        .font(DS2.Font.caption2)
                        .foregroundStyle(referenceColor(within))
                }
            }
        }
    }

    private func referenceColor(_ within: Bool?) -> Color {
        guard let within else { return DS2.Color.pregnancy }
        return within ? DS2.Color.pregnancy : DS2.Color.warning
    }

    // MARK: - 혈당 추이 차트 (맥락별 참고선 색 구분)

    private var glucoseChart: some View {
        DS2Card {
            VStack(alignment: .leading, spacing: DS2.Spacing.sm) {
                Text("혈당 추이").font(DS2.Font.headline).foregroundStyle(DS2.Color.textPrimary)
                Chart(glucoseEntries) { entry in
                    if let value = entry.glucose {
                        PointMark(
                            x: .value("측정일", entry.measuredAt),
                            y: .value("혈당", value)
                        )
                        .foregroundStyle(glucoseColor(entry))
                    }
                }
                .frame(height: 180)
                Text("점 색 — 보라: 측정 맥락별 참고 목표선 이내 · 주황: 초과 (참고용)")
                    .font(DS2.Font.caption2).foregroundStyle(DS2.Color.textSecondary)
            }
        }
    }

    private func glucoseColor(_ entry: PregnancyVitalEntry) -> Color {
        guard let value = entry.glucose,
              let ctx = entry.glucoseContext.flatMap(PregnancyVitalEntry.GlucoseContext.init(rawValue:)) else {
            return DS2.Color.pregnancy
        }
        return PregnancyVitalEntry.glucoseWithinReference(value: value, context: ctx)
            ? DS2.Color.pregnancy : DS2.Color.warning
    }
}

// MARK: - 입력 시트

struct PregnancyVitalEntrySheet: View {
    @Environment(PregnancyViewModel.self) private var pregnancyVM
    @Environment(AuthViewModel.self) private var authVM
    @Environment(\.dismiss) private var dismiss

    @State private var systolic: String = ""
    @State private var diastolic: String = ""
    @State private var glucose: String = ""
    @State private var glucoseContext: PregnancyVitalEntry.GlucoseContext = .fasting
    @State private var fundalHeight: String = ""
    @State private var efw: String = ""
    @State private var isSaving = false

    private var hasBP: Bool { !systolic.isEmpty && !diastolic.isEmpty }
    private var hasGlucose: Bool { !glucose.isEmpty }
    private var hasFundal: Bool { !fundalHeight.isEmpty }
    private var hasEFW: Bool { !efw.isEmpty }
    private var canSave: Bool { hasBP || hasGlucose || hasFundal || hasEFW }

    var body: some View {
        NavigationStack {
            Form {
                Section("혈압 (mmHg)") {
                    HStack {
                        TextField("수축기", text: $systolic).keyboardType(.numberPad)
                        Text("/").foregroundStyle(.secondary)
                        TextField("이완기", text: $diastolic).keyboardType(.numberPad)
                    }
                }
                Section("혈당 (mg/dL)") {
                    TextField("혈당", text: $glucose).keyboardType(.numberPad)
                    Picker("측정 맥락", selection: $glucoseContext) {
                        ForEach(PregnancyVitalEntry.GlucoseContext.allCases) {
                            Text($0.displayName).tag($0)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Section("태아·자궁 (산모수첩 검진 수치)") {
                    HStack {
                        Text("자궁저높이")
                        Spacer(minLength: DS2.Spacing.md)
                        TextField("0", text: $fundalHeight)
                            .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                        Text("cm").foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("태아 추정 체중")
                        Spacer(minLength: DS2.Spacing.md)
                        TextField("0", text: $efw)
                            .keyboardType(.numberPad).multilineTextAlignment(.trailing)
                        Text("g").foregroundStyle(.secondary)
                    }
                }
                Section {
                    HStack(spacing: DS2.Spacing.sm) {
                        Image(systemName: "info.circle.fill").foregroundStyle(.orange)
                        Text("참고용 기록입니다. 임신성 당뇨·고혈압 등 의학적 판단은 담당 의료진과 함께 하세요.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("검진 수치 기록")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") { Task { await save() } }
                        .disabled(isSaving || !canSave)
                }
            }
        }
    }

    private func save() async {
        guard let userId = authVM.currentUserId,
              let pid = pregnancyVM.activePregnancy?.id else { return }
        isSaving = true
        defer { isSaving = false }
        let entry = PregnancyVitalEntry(
            pregnancyId: pid,
            systolic: hasBP ? Int(systolic) : nil,
            diastolic: hasBP ? Int(diastolic) : nil,
            glucose: hasGlucose ? Int(glucose) : nil,
            glucoseContext: hasGlucose ? glucoseContext.rawValue : nil,
            fundalHeight: hasFundal ? Double(fundalHeight) : nil,
            estimatedFetalWeight: hasEFW ? Double(efw) : nil
        )
        await pregnancyVM.addVitalEntry(entry, userId: userId)
        if pregnancyVM.errorMessage == nil { dismiss() }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    let vm = PregnancyViewModel()
    vm.activePregnancy = Pregnancy(lmpDate: nil, dueDate: nil, fetusCount: 1, babyNickname: "둘째")
    vm.vitalEntries = [
        PregnancyVitalEntry(pregnancyId: "p1", systolic: 118, diastolic: 76,
                            glucose: 92, glucoseContext: "fasting")
    ]
    return NavigationStack { PregnancyVitalsView() }
        .environment(vm).environment(AuthViewModel()).tint(DS2.Color.pregnancy)
}
#endif

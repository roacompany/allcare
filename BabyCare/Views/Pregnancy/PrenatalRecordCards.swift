import SwiftUI
import Charts

// MARK: - 산모수첩 디지털 미러 (③검진 §섹션 4)

/// 기존 검진 수치(혈압·혈당·체중)의 최신값을 칩으로 모아 보여주는 카드. 전체 보기 → 추이 시트.
struct MaternalRecordMirrorCard: View {
    let measurements: [MaternalMeasurement]
    let onSeeAll: () -> Void

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        DS2Card(tint: DS2.Color.pregnancy) {
            VStack(alignment: .leading, spacing: DS2.Spacing.md) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: DS2.Spacing.xs) {
                        Text("산모수첩").font(DS2.Font.headline).foregroundStyle(DS2.Color.textPrimary)
                        Text("검진 때 받은 수치를 여기에 모아두세요")
                            .font(DS2.Font.caption).foregroundStyle(DS2.Color.textSecondary)
                    }
                    Spacer(minLength: 0)
                    if !measurements.isEmpty {
                        Button("전체 보기", action: onSeeAll)
                            .font(DS2.Font.caption).tint(DS2.Color.pregnancy)
                    }
                }
                if measurements.isEmpty {
                    emptyGuide
                } else {
                    LazyVGrid(columns: columns, spacing: DS2.Spacing.sm) {
                        ForEach(measurements) { MeasurementChip(measurement: $0) }
                    }
                }
            }
        }
    }

    private var emptyGuide: some View {
        VStack(alignment: .leading, spacing: DS2.Spacing.sm) {
            Text("②기록에서 혈압·혈당·체중을 남기면 여기에 모여요")
                .font(DS2.Font.caption).foregroundStyle(DS2.Color.textSecondary)
            HStack(spacing: DS2.Spacing.sm) {
                ForEach(["혈압", "혈당", "체중"], id: \.self) { label in
                    Text(label).font(DS2.Font.caption2)
                        .padding(.horizontal, DS2.Spacing.sm).padding(.vertical, DS2.Spacing.xs)
                        .background(DS2.Color.textSecondary.opacity(0.1), in: Capsule())
                        .foregroundStyle(DS2.Color.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct MeasurementChip: View {
    let measurement: MaternalMeasurement

    private var a11yLabel: String {
        let ctx = measurement.context.map { ", \($0)" } ?? ""
        return "\(measurement.label) \(measurement.value) \(measurement.unit)\(ctx)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(measurement.label).font(DS2.Font.caption2).foregroundStyle(DS2.Color.textSecondary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(measurement.value).font(DS2.Font.headline).foregroundStyle(DS2.Color.textPrimary)
                Text(measurement.unit).font(DS2.Font.caption2).foregroundStyle(DS2.Color.textSecondary)
            }
            Text(measurement.measuredAt, format: .dateTime.month().day())
                .font(DS2.Font.caption2).foregroundStyle(DS2.Color.textSecondary)
            if let ctx = measurement.context {
                Text(ctx).font(DS2.Font.caption2).foregroundStyle(DS2.Color.pregnancy)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS2.Spacing.sm)
        .background(DS2.Color.pregnancy.opacity(0.08), in: RoundedRectangle(cornerRadius: DS2.Radius.sm))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(a11yLabel)
    }
}

// MARK: - 산모수첩 상세(추이) 시트

struct MaternalRecordDetailSheet: View {
    let vitals: [PregnancyVitalEntry]
    let weights: [PregnancyWeightEntry]
    @Environment(\.dismiss) private var dismiss

    private var sortedWeights: [PregnancyWeightEntry] {
        weights.sorted { $0.measuredAt < $1.measuredAt }
    }
    private var glucoseEntries: [PregnancyVitalEntry] {
        vitals.filter { $0.glucose != nil }.sorted { $0.measuredAt < $1.measuredAt }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS2.Spacing.xl) {
                    PrenatalDisclaimerBanner()
                    if !sortedWeights.isEmpty { weightSection }
                    if !glucoseEntries.isEmpty { glucoseSection }
                    if sortedWeights.isEmpty && glucoseEntries.isEmpty {
                        Text("아직 기록된 수치가 없어요")
                            .font(DS2.Font.caption).foregroundStyle(DS2.Color.textSecondary)
                    }
                }
                .padding(DS2.Spacing.lg)
            }
            .navigationTitle("산모수첩 수치")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("닫기") { dismiss() } }
            }
        }
    }

    private var weightSection: some View {
        VStack(alignment: .leading, spacing: DS2.Spacing.sm) {
            Text("체중 추이").font(DS2.Font.headline)
            Chart(sortedWeights) { entry in
                LineMark(x: .value("날짜", entry.measuredAt), y: .value("체중", entry.weight))
                    .foregroundStyle(DS2.Color.pregnancy)
                PointMark(x: .value("날짜", entry.measuredAt), y: .value("체중", entry.weight))
                    .foregroundStyle(DS2.Color.pregnancy)
            }
            .frame(height: 160)
        }
    }

    private var glucoseSection: some View {
        VStack(alignment: .leading, spacing: DS2.Spacing.sm) {
            Text("혈당 기록").font(DS2.Font.headline)
            ForEach(glucoseEntries) { entry in
                HStack {
                    Text(entry.measuredAt, format: .dateTime.month().day())
                        .font(DS2.Font.caption).foregroundStyle(DS2.Color.textSecondary)
                    if let ctx = entry.glucoseContext.flatMap({ PregnancyVitalEntry.GlucoseContext(rawValue: $0)?.displayName }) {
                        Text(ctx).font(DS2.Font.caption2).foregroundStyle(DS2.Color.pregnancy)
                    }
                    Spacer()
                    Text("\(entry.glucose ?? 0) mg/dL").font(DS2.Font.subheadline)
                }
            }
        }
    }
}

// MARK: - 국민행복카드 바우처 (③검진 §섹션 3)

/// 국민행복카드 임신·출산 진료비 바우처 안내 카드(정적·카드사 미연동, 커머스 0).
struct HappyCardVoucherCard: View {
    let fetusCount: Int?
    var usedAmount: Int?
    var onSaveUsed: ((Int) -> Void)?
    @State private var showUsage = false
    @State private var isEditingUsed = false
    @State private var usedDraft = ""

    private var amount: Int { HappyCardVoucher.supportAmount(fetusCount: fetusCount) }
    private var isMulti: Bool { (fetusCount ?? 1) >= 2 }
    private var progress: Double { HappyCardVoucher.usedProgress(used: usedAmount ?? 0, total: amount) }
    private var remaining: Int { HappyCardVoucher.remaining(used: usedAmount ?? 0, total: amount) }
    private var isOver: Bool { HappyCardVoucher.isOverBudget(used: usedAmount ?? 0, total: amount) }

    var body: some View {
        DS2Card(tint: DS2.Color.pregnancy) {
            VStack(alignment: .leading, spacing: DS2.Spacing.md) {
                Text("국민행복카드 (임신·출산 진료비)")
                    .font(DS2.Font.headline).foregroundStyle(DS2.Color.textPrimary)
                HStack(alignment: .firstTextBaseline, spacing: DS2.Spacing.xs) {
                    Text("\(amount / 10000)").font(DS2.Font.title).foregroundStyle(DS2.Color.pregnancy)
                    Text("만 원 지원").font(DS2.Font.subheadline).foregroundStyle(DS2.Color.textSecondary)
                    Spacer(minLength: 0)
                    Text(isMulti ? "다태아 기준" : "단태아 기준")
                        .font(DS2.Font.caption2)
                        .padding(.horizontal, DS2.Spacing.sm).padding(.vertical, DS2.Spacing.xs)
                        .background(DS2.Color.pregnancy.opacity(0.14), in: Capsule())
                        .foregroundStyle(DS2.Color.pregnancy)
                }
                if onSaveUsed != nil { usageSection }
                Text(HappyCardVoucher.periodNote)
                    .font(DS2.Font.caption).foregroundStyle(DS2.Color.textSecondary)
                DisclosureGroup(isExpanded: $showUsage) {
                    VStack(alignment: .leading, spacing: DS2.Spacing.xs) {
                        Label(HappyCardVoucher.usageNote, systemImage: "cross.case").font(DS2.Font.caption)
                        Label(HappyCardVoucher.applyNote, systemImage: "doc.text").font(DS2.Font.caption)
                    }
                    .foregroundStyle(DS2.Color.textSecondary)
                    .padding(.top, DS2.Spacing.xs)
                } label: {
                    Text("사용처·신청 안내").font(DS2.Font.subheadline).foregroundStyle(DS2.Color.pregnancy)
                }
                .tint(DS2.Color.pregnancy)
                Text(HappyCardVoucher.disclaimer)
                    .font(DS2.Font.caption2).foregroundStyle(DS2.Color.textSecondary)
            }
        }
    }

    /// 사용 진행 바 + 잔여 + 수동 입력(만 원 단위). 카드사 미연동 — 직접 기록.
    @ViewBuilder private var usageSection: some View {
        VStack(alignment: .leading, spacing: DS2.Spacing.sm) {
            if usedAmount != nil {
                ProgressView(value: progress).tint(isOver ? .orange : DS2.Color.pregnancy)
                HStack {
                    Text("사용 \((usedAmount ?? 0) / 10000)만 원")
                        .font(DS2.Font.caption).foregroundStyle(DS2.Color.textSecondary)
                    Spacer(minLength: 0)
                    Text("잔여 \(remaining / 10000)만 원")
                        .font(DS2.Font.caption.weight(.semibold)).foregroundStyle(DS2.Color.pregnancy)
                }
                .accessibilityElement(children: .combine)
                if isOver {
                    Label("입력한 사용액이 지원 한도를 넘었어요", systemImage: "exclamationmark.triangle")
                        .font(DS2.Font.caption2).foregroundStyle(.orange)
                }
            } else {
                Text("사용액을 입력해두면 잔여 금액을 한눈에 볼 수 있어요")
                    .font(DS2.Font.caption).foregroundStyle(DS2.Color.textSecondary)
            }
            if isEditingUsed {
                HStack(spacing: DS2.Spacing.sm) {
                    TextField("사용액 (만 원)", text: $usedDraft)
                        .keyboardType(.numberPad)
                        .font(DS2.Font.subheadline)
                    Button("저장", action: saveUsed)
                        .font(DS2.Font.subheadline).tint(DS2.Color.pregnancy)
                        .disabled(usedDraft.filter(\.isNumber).isEmpty)
                    Button("취소") { isEditingUsed = false; usedDraft = "" }
                        .font(DS2.Font.subheadline).tint(DS2.Color.textSecondary)
                }
            } else {
                Button(usedAmount == nil ? "사용액 입력" : "사용액 수정") {
                    usedDraft = usedAmount.map { String($0 / 10000) } ?? ""
                    isEditingUsed = true
                }
                .font(DS2.Font.subheadline).tint(DS2.Color.pregnancy)
            }
        }
        .padding(.vertical, DS2.Spacing.xs)
    }

    private func saveUsed() {
        let digits = usedDraft.filter(\.isNumber)
        guard let manwon = Int(digits) else { isEditingUsed = false; return }
        onSaveUsed?(manwon * 10_000)
        usedDraft = ""
        isEditingUsed = false
    }
}

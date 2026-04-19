import SwiftUI
import Charts

struct PregnancyWeightView: View {
    @Environment(PregnancyViewModel.self) private var pregnancyVM
    @Environment(AuthViewModel.self) private var authVM

    @State private var showAddSheet = false

    private var sortedEntries: [PregnancyWeightEntry] {
        pregnancyVM.weightEntries.sorted(by: { $0.measuredAt < $1.measuredAt })
    }

    private var prePregnancyWeight: Double? {
        pregnancyVM.activePregnancy?.prePregnancyWeight
    }

    private var weightUnit: String {
        pregnancyVM.activePregnancy?.weightUnit ?? "kg"
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

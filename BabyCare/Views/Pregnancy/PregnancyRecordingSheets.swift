import SwiftUI

// MARK: - KickRecordingSheet
// 태동 기록 빠른 입력 시트 (RecordingView 진입점용).
// 상세 기능은 KickSessionView에서 구현.

struct KickRecordingSheet: View {
    @Environment(PregnancyViewModel.self) private var pregnancyVM
    @Environment(AuthViewModel.self) private var authVM
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            KickSessionView()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("닫기") { dismiss() }
                    }
                }
        }
    }
}

// MARK: - PregnancyWeightEntrySheet
// 체중 기록 빠른 입력 시트 (RecordingView 진입점용).

struct PregnancyWeightEntrySheet: View {
    @Environment(PregnancyViewModel.self) private var pregnancyVM
    @Environment(AuthViewModel.self) private var authVM
    @Environment(\.dismiss) private var dismiss

    @State private var weight: String = ""
    @State private var unit: String = "kg"
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
                }

                Section {
                    HStack(spacing: 10) {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(.orange)
                        Text("체중 변화는 참고용 기록입니다. 의학적 판단은 담당 의료진에게 문의하세요.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
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
            unit: unit
        )
        await pregnancyVM.addWeightEntry(entry, userId: userId)
        if pregnancyVM.errorMessage == nil {
            dismiss()
        }
    }
}

// MARK: - PregnancySymptomMemoSheet
// 증상 메모 빠른 입력 시트 (RecordingView 진입점용).

struct PregnancySymptomMemoSheet: View {
    @Environment(PregnancyViewModel.self) private var pregnancyVM
    @Environment(AuthViewModel.self) private var authVM
    @Environment(\.dismiss) private var dismiss

    @State private var memo: String = ""
    @State private var severity: PregnancySymptom.Severity?
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section(LocalizedStringKey("pregnancy.symptom.section.memo")) {
                    TextField(LocalizedStringKey("pregnancy.symptom.placeholder"), text: $memo, axis: .vertical)
                        .lineLimit(4...8)
                }

                Section(LocalizedStringKey("pregnancy.symptom.section.severity")) {
                    Picker(LocalizedStringKey("pregnancy.symptom.section.severity"), selection: $severity) {
                        Text(LocalizedStringKey("pregnancy.symptom.severity.unspecified"))
                            .tag(PregnancySymptom.Severity?.none)
                        Text(LocalizedStringKey("pregnancy.symptom.severity.mild"))
                            .tag(PregnancySymptom.Severity?.some(.mild))
                        Text(LocalizedStringKey("pregnancy.symptom.severity.moderate"))
                            .tag(PregnancySymptom.Severity?.some(.moderate))
                        Text(LocalizedStringKey("pregnancy.symptom.severity.severe"))
                            .tag(PregnancySymptom.Severity?.some(.severe))
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    HStack(spacing: 10) {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(.orange)
                        Text(LocalizedStringKey("pregnancy.symptom.disclaimer"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(LocalizedStringKey("pregnancy.symptom.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        Task { await save() }
                    }
                    .disabled(isSaving || memo.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() async {
        guard let userId = authVM.currentUserId,
              let pid = pregnancyVM.activePregnancy?.id else { return }
        isSaving = true
        defer { isSaving = false }
        let trimmed = memo.trimmingCharacters(in: .whitespacesAndNewlines)
        let symptom = PregnancySymptom(
            pregnancyId: pid,
            memo: trimmed,
            severity: severity
        )
        await pregnancyVM.addSymptom(symptom, userId: userId)
        if pregnancyVM.errorMessage == nil {
            dismiss()
        }
    }
}

// MARK: - PregnancyMoodSheet
// 정서(기분) 체크인 시트 — 가벼운 기분 기록 + 선택 메모. 의료적 우울 스크리닝 아님.

struct PregnancyMoodSheet: View {
    @Environment(PregnancyViewModel.self) private var pregnancyVM
    @Environment(AuthViewModel.self) private var authVM
    @Environment(\.dismiss) private var dismiss

    @State private var mood: PregnancyMood.Mood = .okay
    @State private var memo: String = ""
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("오늘 기분") {
                    HStack(spacing: 6) {
                        ForEach(PregnancyMood.Mood.allCases) { option in
                            Button {
                                mood = option
                            } label: {
                                VStack(spacing: 4) {
                                    Text(option.emoji).font(.title)
                                    Text(option.displayName)
                                        .font(.caption2)
                                        .multilineTextAlignment(.center)
                                        .foregroundStyle(mood == option ? DS2.Color.pregnancy : .secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(
                                    mood == option ? DS2.Color.pregnancy.opacity(0.12) : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 10)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section("메모 (선택)") {
                    TextField("오늘 어땠는지 가볍게 적어보세요", text: $memo, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section {
                    HStack(spacing: 10) {
                        Image(systemName: "heart.circle.fill")
                            .foregroundStyle(DS2.Color.pregnancy)
                        Text("가벼운 기분 기록이에요. 힘든 마음이 이어지면 혼자 두지 말고 주변이나 의료진에게 이야기해 보세요.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("기분 기록")
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
        guard let userId = authVM.currentUserId,
              let pid = pregnancyVM.activePregnancy?.id else { return }
        isSaving = true
        defer { isSaving = false }
        let trimmed = memo.trimmingCharacters(in: .whitespacesAndNewlines)
        let record = PregnancyMood(
            pregnancyId: pid,
            mood: mood,
            memo: trimmed.isEmpty ? nil : trimmed
        )
        await pregnancyVM.addMood(record, userId: userId)
        if pregnancyVM.errorMessage == nil {
            dismiss()
        }
    }
}

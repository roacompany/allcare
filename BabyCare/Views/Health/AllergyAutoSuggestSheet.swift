import SwiftUI

// MARK: - AllergyAutoSuggestSheet
// 이유식 기록 시 부정적 반응 감지 → 알레르기 기록 자동 생성 제안
// 기록 기반 분류 · 참고용 — 의학적 진단이 아닙니다.

struct AllergyAutoSuggestSheet: View {
    @Environment(\.dismiss) private var dismiss

    let suggestedRecord: AllergyRecord
    let onConfirm: (AllergyRecord) async -> Void

    @State private var allergenName: String
    @State private var selectedReactionType: AllergyReactionType
    @State private var selectedSeverity: AllergySeverity
    @State private var noteText: String
    @State private var isSaving = false

    init(
        suggestedRecord: AllergyRecord,
        onConfirm: @escaping (AllergyRecord) async -> Void
    ) {
        self.suggestedRecord = suggestedRecord
        self.onConfirm = onConfirm
        _allergenName = State(initialValue: suggestedRecord.allergenName)
        _selectedReactionType = State(initialValue: suggestedRecord.reactionType)
        _selectedSeverity = State(initialValue: suggestedRecord.severity)
        _noteText = State(initialValue: suggestedRecord.note ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 10) {
                        Image(systemName: "leaf.arrow.triangle.circlepath")
                            .font(.title2)
                            .foregroundStyle(AppColors.warmOrangeColor)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(NSLocalizedString("food.autosuggest.sheet.title", comment: ""))
                                .font(.subheadline.weight(.semibold))
                            Text(NSLocalizedString("food.autosuggest.sheet.subtitle", comment: ""))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section(NSLocalizedString("food.autosuggest.section.allergen", comment: "")) {
                    TextField(
                        NSLocalizedString("food.autosuggest.allergen.placeholder", comment: ""),
                        text: $allergenName
                    )
                }

                Section(NSLocalizedString("food.autosuggest.section.reactionType", comment: "")) {
                    Picker(
                        NSLocalizedString("food.autosuggest.reactionType.label", comment: ""),
                        selection: $selectedReactionType
                    ) {
                        ForEach(AllergyReactionType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                }

                Section(NSLocalizedString("food.autosuggest.section.severity", comment: "")) {
                    Picker(
                        NSLocalizedString("food.autosuggest.severity.label", comment: ""),
                        selection: $selectedSeverity
                    ) {
                        ForEach(AllergySeverity.allCases, id: \.self) { severity in
                            Text(severity.displayName).tag(severity)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section(NSLocalizedString("food.autosuggest.section.note", comment: "")) {
                    TextField(
                        NSLocalizedString("food.autosuggest.note.placeholder", comment: ""),
                        text: $noteText,
                        axis: .vertical
                    )
                    .lineLimit(3...)
                }

                Section {
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                        Text(NSLocalizedString("food.autosuggest.disclaimer", comment: ""))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(NSLocalizedString("food.autosuggest.nav.title", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("food.autosuggest.action.skip", comment: "")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text(NSLocalizedString("food.autosuggest.action.save", comment: ""))
                                .bold()
                        }
                    }
                    .disabled(allergenName.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
        }
    }

    // MARK: - Save

    private func save() async {
        isSaving = true
        var record = suggestedRecord
        record.allergenName = allergenName.trimmingCharacters(in: .whitespaces)
        record.reactionType = selectedReactionType
        record.severity = selectedSeverity
        record.note = noteText.isEmpty ? nil : noteText
        await onConfirm(record)
        isSaving = false
        dismiss()
    }
}

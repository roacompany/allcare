import SwiftUI

/// 예방접종 후 부작용 기록 입력 시트.
/// 정보 보관용이며 의학적 진단이 아닙니다.
struct VaccineSideEffectSheet: View {
    let vaccination: Vaccination
    let onSave: ([VaccineSideEffect]) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var selectedTypes: Set<VaccineSideEffect.SideEffectType> = []
    @State private var selectedSeverity: VaccineSideEffect.Severity = .mild
    @State private var note: String = ""
    @State private var recordedAt: Date = Date()

    var body: some View {
        NavigationStack {
            Form {
                vaccinationInfoSection
                sideEffectTypeSection
                severitySection
                noteSection
                disclaimerSection
            }
            .navigationTitle(NSLocalizedString("vaccination.sideEffect.sheet.title", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("vaccination.sideEffect.sheet.cancel", comment: "")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("vaccination.sideEffect.sheet.save", comment: "")) {
                        saveSideEffects()
                    }
                    .disabled(selectedTypes.isEmpty)
                }
            }
        }
    }

    // MARK: - Sections

    private var vaccinationInfoSection: some View {
        Section {
            HStack {
                Image(systemName: "syringe.fill")
                    .foregroundStyle(AppColors.healthColor)
                Text("\(vaccination.vaccine.displayName) \(vaccination.doseNumber)차")
                    .font(.subheadline.weight(.medium))
            }
            DatePicker(
                NSLocalizedString("vaccination.sideEffect.recordedAt", comment: ""),
                selection: $recordedAt,
                in: ...Date(),
                displayedComponents: [.date, .hourAndMinute]
            )
            .environment(\.locale, Locale(identifier: "ko_KR"))
        } header: {
            Text(NSLocalizedString("vaccination.sideEffect.info.header", comment: ""))
        }
    }

    private var sideEffectTypeSection: some View {
        Section {
            ForEach(VaccineSideEffect.SideEffectType.allCases, id: \.self) { type in
                Button {
                    if selectedTypes.contains(type) {
                        selectedTypes.remove(type)
                    } else {
                        selectedTypes.insert(type)
                    }
                } label: {
                    HStack {
                        Image(systemName: type.icon)
                            .foregroundStyle(AppColors.healthColor)
                            .frame(width: 24)
                        Text(type.displayName)
                            .foregroundStyle(.primary)
                        Spacer()
                        if selectedTypes.contains(type) {
                            Image(systemName: "checkmark")
                                .foregroundStyle(AppColors.healthColor)
                        }
                    }
                }
            }
        } header: {
            Text(NSLocalizedString("vaccination.sideEffect.type.header", comment: ""))
        }
    }

    private var severitySection: some View {
        Section {
            Picker(NSLocalizedString("vaccination.sideEffect.severity.label", comment: ""), selection: $selectedSeverity) {
                ForEach(VaccineSideEffect.Severity.allCases, id: \.self) { severity in
                    Text(severity.displayName).tag(severity)
                }
            }
            .pickerStyle(.segmented)
        } header: {
            Text(NSLocalizedString("vaccination.sideEffect.severity.header", comment: ""))
        }
    }

    private var noteSection: some View {
        Section {
            TextField(
                NSLocalizedString("vaccination.sideEffect.note.placeholder", comment: ""),
                text: $note,
                axis: .vertical
            )
            .lineLimit(3...5)
        } header: {
            Text(NSLocalizedString("vaccination.sideEffect.note.header", comment: ""))
        }
    }

    private var disclaimerSection: some View {
        Section {
            Text(NSLocalizedString("vaccination.sideEffect.disclaimer", comment: ""))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Save

    private func saveSideEffects() {
        let effects = selectedTypes.map { type in
            VaccineSideEffect(
                type: type,
                severity: selectedSeverity,
                recordedAt: recordedAt,
                note: note.isEmpty ? nil : note
            )
        }
        onSave(effects)
        dismiss()
    }
}

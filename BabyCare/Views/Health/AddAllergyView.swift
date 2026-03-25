import SwiftUI

struct AddAllergyView: View {
    @Environment(AuthViewModel.self) private var authVM
    @Environment(BabyViewModel.self) private var babyVM
    @Environment(\.dismiss) private var dismiss

    let onSave: (AllergyRecord) -> Void

    @State private var selectedAllergen: CommonAllergen? = nil
    @State private var customAllergenName = ""
    @State private var reactionType: AllergyReactionType = .skin
    @State private var severity: AllergySeverity = .mild
    @State private var selectedSymptoms: Set<String> = []
    @State private var date = Date()
    @State private var note = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let allSymptoms = ["발진", "두드러기", "구토", "설사", "호흡곤란", "부종", "기타"]
    private let service = FirestoreService.shared

    private var allergenName: String {
        if let allergen = selectedAllergen, allergen != .other {
            return allergen.displayName
        }
        return customAllergenName.trimmingCharacters(in: .whitespaces)
    }

    private var canSave: Bool {
        !allergenName.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                // 알레르겐 선택
                allergenSection

                // 반응 유형
                Section("반응 유형") {
                    Picker("반응 유형", selection: $reactionType) {
                        ForEach(AllergyReactionType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                }

                // 심각도
                Section("심각도") {
                    Picker("심각도", selection: $severity) {
                        ForEach(AllergySeverity.allCases, id: \.self) { s in
                            Text(s.displayName).tag(s)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))

                    HStack {
                        Spacer()
                        SeverityIndicator(severity: severity)
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }

                // 증상 체크리스트
                symptomsSection

                // 날짜 및 메모
                Section("날짜 및 메모") {
                    DatePicker("발생 날짜", selection: $date, in: ...Date(), displayedComponents: .date)
                        .environment(\.locale, Locale(identifier: "ko_KR"))
                    TextField("메모 (선택)", text: $note, axis: .vertical)
                        .lineLimit(3...5)
                }
            }
            .navigationTitle("알레르기 기록 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        Task { await saveRecord() }
                    }
                    .disabled(!canSave || isSaving)
                }
            }
            .alert("오류", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("확인") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: - Allergen Section

    private var allergenSection: some View {
        Section("알레르겐") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(CommonAllergen.allCases, id: \.self) { allergen in
                        AllergenChip(
                            title: allergen.displayName,
                            isSelected: selectedAllergen == allergen
                        ) {
                            if selectedAllergen == allergen {
                                selectedAllergen = nil
                            } else {
                                selectedAllergen = allergen
                                if allergen != .other {
                                    customAllergenName = ""
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

            if selectedAllergen == .other || selectedAllergen == nil {
                TextField(
                    selectedAllergen == .other ? "알레르겐 직접 입력" : "또는 직접 입력",
                    text: $customAllergenName
                )
                .autocorrectionDisabled()
            }
        }
    }

    // MARK: - Symptoms Section

    private var symptomsSection: some View {
        Section("증상") {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(allSymptoms, id: \.self) { symptom in
                    SymptomToggle(
                        title: symptom,
                        isSelected: selectedSymptoms.contains(symptom)
                    ) {
                        if selectedSymptoms.contains(symptom) {
                            selectedSymptoms.remove(symptom)
                        } else {
                            selectedSymptoms.insert(symptom)
                        }
                    }
                }
            }
            .padding(.vertical, 4)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        }
    }

    // MARK: - Save

    private func saveRecord() async {
        guard canSave,
              let userId = authVM.currentUserId,
              let baby = babyVM.selectedBaby else { return }

        isSaving = true
        let record = AllergyRecord(
            babyId: baby.id,
            allergenName: allergenName,
            reactionType: reactionType,
            severity: severity,
            date: date,
            symptoms: Array(selectedSymptoms).sorted(),
            note: note.trimmingCharacters(in: .whitespaces).isEmpty ? nil : note.trimmingCharacters(in: .whitespaces)
        )

        do {
            try await service.saveAllergyRecord(record, userId: userId, babyId: baby.id)
            onSave(record)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }
}

// MARK: - Allergen Chip

private struct AllergenChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isSelected ? AppColors.coralColor : Color(.systemGray6))
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Symptom Toggle

private struct SymptomToggle: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? AppColors.coralColor : .secondary)
                    .font(.body)
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? AppColors.coralColor.opacity(0.1) : Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Severity Indicator

private struct SeverityIndicator: View {
    let severity: AllergySeverity

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(severityColor)
                .frame(width: 10, height: 10)
            Text(severityLabel)
                .font(.subheadline)
                .foregroundStyle(severityColor)
        }
    }

    private var severityColor: Color {
        switch severity {
        case .mild: return .green
        case .moderate: return .orange
        case .severe: return .red
        }
    }

    private var severityLabel: String {
        switch severity {
        case .mild: return "가벼운 반응으로 관찰이 필요합니다"
        case .moderate: return "중간 반응으로 주의가 필요합니다"
        case .severe: return "심각한 반응으로 즉시 진료가 필요합니다"
        }
    }
}

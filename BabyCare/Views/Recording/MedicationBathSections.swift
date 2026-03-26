import SwiftUI

// MARK: - MedicationSection

struct MedicationSection: View {
    @Environment(ActivityViewModel.self) var activityVM
    let accentColor: Color

    let suggestions = ["타이레놀", "이부프로펜", "콧물약", "소화제", "영양제"]
    let dosageChips = ["2.5ml", "5ml", "10ml", "반정", "1정"]

    var body: some View {
        @Bindable var vm = activityVM

        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 4) {
                Label("투약 정보", systemImage: "pills.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
                Text("*")
                    .font(.subheadline.bold())
                    .foregroundStyle(.red)
            }

            TextField("약 이름 입력 (필수)", text: $vm.medicationName)
                .padding(14)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .font(.body)

            // Suggestion chips
            Text("자주 사용하는 약")
                .font(.caption)
                .foregroundStyle(.tertiary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(suggestions, id: \.self) { name in
                        Button(name) {
                            activityVM.medicationName = name
                        }
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            activityVM.medicationName == name
                                ? accentColor
                                : accentColor.opacity(0.1)
                        )
                        .foregroundStyle(
                            activityVM.medicationName == name ? .white : accentColor
                        )
                        .clipShape(Capsule())
                    }
                }
            }

            Divider()

            // 용량 입력
            Label("용량", systemImage: "drop.fill")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)

            TextField("용량 입력 (예: 5ml)", text: $vm.medicationDosage)
                .padding(14)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            Text("자주 사용하는 용량")
                .font(.caption)
                .foregroundStyle(.tertiary)

            HStack(spacing: 8) {
                ForEach(dosageChips, id: \.self) { dosage in
                    Button(dosage) {
                        activityVM.medicationDosage = activityVM.medicationDosage == dosage ? "" : dosage
                    }
                    .font(.system(size: 13, weight: .medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        activityVM.medicationDosage == dosage
                            ? accentColor
                            : accentColor.opacity(0.1)
                    )
                    .foregroundStyle(
                        activityVM.medicationDosage == dosage ? .white : accentColor
                    )
                    .clipShape(Capsule())
                }
            }
        }
        .padding()
        .background(accentColor.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }
}

// MARK: - BathSection

struct BathSection: View {
    let accentColor: Color

    var body: some View {
        VStack(spacing: 8) {
            TimerView(type: .bath, accentColor: accentColor)
                .padding(.vertical, 4)

            Text("목욕 시작 시 타이머를 켜세요")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(accentColor.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }
}

#Preview {
    HealthRecordView()
        .environment(ActivityViewModel())
        .environment(BabyViewModel())
        .environment(AuthViewModel())
}

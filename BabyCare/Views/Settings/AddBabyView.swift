import SwiftUI

struct AddBabyView: View {
    @Environment(BabyViewModel.self) private var babyVM
    @Environment(AuthViewModel.self) private var authVM
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var vm = babyVM

        NavigationStack {
            Form {
                Section("기본 정보") {
                    TextField("아기 이름", text: $vm.babyName)

                    DatePicker(
                        "생년월일",
                        selection: $vm.babyBirthDate,
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    .environment(\.locale, Locale(identifier: "ko_KR"))

                    Picker("성별", selection: $vm.babyGender) {
                        ForEach(Baby.Gender.allCases, id: \.self) { gender in
                            Text("\(gender.emoji) \(gender.displayName)")
                                .tag(gender)
                        }
                    }
                }

                Section("추가 정보 (선택)") {
                    Picker("혈액형", selection: $vm.babyBloodType) {
                        Text("선택 안함").tag(Baby.BloodType?.none)
                        ForEach(Baby.BloodType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(Baby.BloodType?.some(type))
                        }
                    }
                }

                if let error = babyVM.errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("아기 등록")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        babyVM.resetForm()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        Task {
                            guard let userId = authVM.currentUserId else { return }
                            await babyVM.addBaby(userId: userId)
                            if babyVM.errorMessage == nil {
                                dismiss()
                            }
                        }
                    }
                    .disabled(!babyVM.isFormValid || babyVM.isLoading)
                }
            }
        }
    }
}

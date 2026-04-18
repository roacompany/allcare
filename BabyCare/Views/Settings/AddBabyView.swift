import SwiftUI

struct AddBabyView: View {
    @Environment(BabyViewModel.self) private var babyVM
    @Environment(AuthViewModel.self) private var authVM
    @Environment(PregnancyViewModel.self) private var pregnancyVM
    @Environment(\.dismiss) private var dismiss

    @State private var showPregnancyRegistration = false

    private var pregnancyVMHasActive: Bool {
        pregnancyVM.activePregnancy != nil
    }

    var body: some View {
        @Bindable var vm = babyVM

        NavigationStack {
            Form {
                if FeatureFlags.pregnancyModeEnabled {
                    Section {
                        Button {
                            showPregnancyRegistration = true
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "figure.and.child.holdinghands")
                                    .font(.title3)
                                    .foregroundStyle(AppColors.primaryAccent)
                                    .frame(width: 32)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("아직 태어나지 않았나요?")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    Text("임신 모드로 D-day · 주차 · 태동 기록")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }

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
            .sheet(isPresented: $showPregnancyRegistration, onDismiss: {
                // 임신 등록 성공 시 AddBabyView도 함께 닫기 + 미사용 babyVM 폼 잔재 제거
                if pregnancyVMHasActive {
                    babyVM.resetForm()
                    dismiss()
                }
            }) {
                PregnancyRegistrationView()
            }
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

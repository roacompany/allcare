import SwiftUI

// MARK: - PregnancyTransitionSheet
// 출산 전환 시트.
// 2단계 확인: 폼 입력 → Alert 확인 → 전환 실행
// 성공 시 checkmark 아이콘 2초 표시 후 dismiss.

struct PregnancyTransitionSheet: View {
    @Environment(PregnancyViewModel.self) private var pregnancyVM
    @Environment(AuthViewModel.self) private var authVM
    @Environment(\.dismiss) private var dismiss

    // MARK: - Form State

    @State private var babyName: String
    @State private var gender: Baby.Gender
    @State private var birthDate: Date = Date()

    // MARK: - UI State

    @State private var showConfirmAlert = false
    @State private var phase: TransitionPhase = .form

    enum TransitionPhase {
        case form
        case success
        case failure(String)
    }

    // MARK: - Init (prefill from pregnancy)

    init(pregnancy: Pregnancy) {
        _babyName = State(initialValue: pregnancy.babyNickname ?? "")
        let prefillGender: Baby.Gender
        if let ultra = pregnancy.ultrasoundGender {
            switch ultra.rawValue {
            case "남아": prefillGender = .male
            case "여아": prefillGender = .female
            default: prefillGender = .male
            }
        } else {
            prefillGender = .male
        }
        _gender = State(initialValue: prefillGender)
    }

    // MARK: - Computed

    private var isFormValid: Bool {
        !babyName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                switch phase {
                case .form:
                    formContent
                case .success:
                    successContent
                case .failure(let message):
                    failureContent(message: message)
                }
            }
            .navigationTitle("출산 완료 등록")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if case .form = phase {
                        Button("취소") { dismiss() }
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
        .alert(
            "출산 완료로 전환하시겠어요?",
            isPresented: $showConfirmAlert
        ) {
            Button("전환 진행", role: .destructive) {
                performTransition()
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("되돌리려면 설정 > 이전 임신에서 복구해야 합니다.")
        }
    }

    // MARK: - Form Content

    private var formContent: some View {
        Form {
            Section {
                HStack(spacing: 10) {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(AppColors.primaryAccent)
                    Text("아기 정보를 입력해 주세요. 임신 기록은 아카이브로 보관됩니다.")
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                }
                .padding(.vertical, 4)
            }
            .listRowBackground(
                RoundedRectangle(cornerRadius: 10)
                    .fill(AppColors.primaryAccent.opacity(0.10))
            )

            Section("아기 이름") {
                TextField("이름을 입력하세요", text: $babyName)
            }

            Section("성별") {
                Picker("성별", selection: $gender) {
                    ForEach(Baby.Gender.allCases, id: \.self) { g in
                        Text(g.displayName).tag(g)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("실제 출생일") {
                DatePicker(
                    "출생일",
                    selection: $birthDate,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .environment(\.locale, Locale(identifier: "ko_KR"))
            }

            Section {
                Button {
                    showConfirmAlert = true
                } label: {
                    HStack {
                        Spacer()
                        Text("전환 진행")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isFormValid ? AppColors.primaryAccent : Color.gray.opacity(0.4))
                )
                .disabled(!isFormValid)
            }
        }
    }

    // MARK: - Success Content

    private var successContent: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(AppColors.primaryAccent)

            Text("아기 등록이 완료되었어요!")
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)

            Text("\(babyName)")
                .font(.title3)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Failure Content

    private func failureContent(message: String) -> some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "xmark.circle")
                .font(.system(size: 64))
                .foregroundStyle(.red)

            Text("전환에 실패했습니다.")
                .font(.title3.weight(.semibold))

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("다시 시도") {
                phase = .form
            }
            .buttonStyle(.borderedProminent)
            .tint(AppColors.primaryAccent)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Transition Action

    private func performTransition() {
        guard let userId = authVM.currentUserId else { return }
        Task {
            do {
                _ = try await pregnancyVM.transitionToBaby(
                    babyName: babyName.trimmingCharacters(in: .whitespaces),
                    gender: gender,
                    birthDate: birthDate,
                    userId: userId
                )
                phase = .success
                try? await Task.sleep(for: .seconds(2))
                dismiss()
            } catch {
                phase = .failure(error.localizedDescription)
            }
        }
    }
}

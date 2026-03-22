import SwiftUI

struct BabyDetailView: View {
    @Environment(BabyViewModel.self) private var babyVM
    @Environment(AuthViewModel.self) private var authVM
    @Environment(\.dismiss) private var dismiss

    let baby: Baby

    @State private var name: String = ""
    @State private var birthDate = Date()
    @State private var gender: Baby.Gender = .male
    @State private var bloodType: Baby.BloodType?
    @State private var showDeleteAlert = false
    @State private var isSaving = false
    @State private var savedMessage: String?

    var body: some View {
        Form {
            Section("기본 정보") {
                TextField("이름", text: $name)

                DatePicker(
                    "생년월일",
                    selection: $birthDate,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .environment(\.locale, Locale(identifier: "ko_KR"))

                Picker("성별", selection: $gender) {
                    ForEach(Baby.Gender.allCases, id: \.self) { g in
                        Text("\(g.emoji) \(g.displayName)").tag(g)
                    }
                }
            }

            Section("추가 정보") {
                Picker("혈액형", selection: $bloodType) {
                    Text("선택 안함").tag(Baby.BloodType?.none)
                    ForEach(Baby.BloodType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(Baby.BloodType?.some(type))
                    }
                }

                HStack {
                    Text("나이")
                    Spacer()
                    Text(baby.ageText)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("등록일")
                    Spacer()
                    Text(DateFormatters.fullDate.string(from: baby.createdAt))
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Button("저장") {
                    save()
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
            }

            Section {
                Button(role: .destructive) {
                    showDeleteAlert = true
                } label: {
                    Label("아기 삭제", systemImage: "trash.fill")
                }
            }
        }
        .navigationTitle(baby.name)
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .bottom) {
            if let msg = savedMessage {
                Text(msg)
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut, value: savedMessage)
        .onAppear {
            name = baby.name
            birthDate = baby.birthDate
            gender = baby.gender
            bloodType = baby.bloodType
        }
        .alert("아기 삭제", isPresented: $showDeleteAlert) {
            Button("취소", role: .cancel) {}
            Button("삭제", role: .destructive) {
                Task {
                    guard let userId = authVM.currentUserId else { return }
                    await babyVM.deleteBaby(baby, userId: userId)
                    dismiss()
                }
            }
        } message: {
            Text("\(baby.name)의 모든 기록이 삭제됩니다. 되돌릴 수 없습니다.")
        }
    }

    private func save() {
        guard let userId = authVM.currentUserId else { return }
        isSaving = true
        var updated = baby
        updated.name = name.trimmingCharacters(in: .whitespaces)
        updated.birthDate = birthDate
        updated.gender = gender
        updated.bloodType = bloodType
        Task {
            await babyVM.updateBaby(updated, userId: userId)
            isSaving = false
            if babyVM.errorMessage == nil {
                withAnimation { savedMessage = "\(updated.name) 정보 저장됨" }
                try? await Task.sleep(for: .seconds(1.5))
                dismiss()
            }
        }
    }
}

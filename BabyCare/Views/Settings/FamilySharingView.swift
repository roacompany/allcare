import SwiftUI

struct FamilySharingView: View {
    @Environment(AuthViewModel.self) private var authVM
    @Environment(BabyViewModel.self) private var babyVM

    @State private var vm = FamilySharingViewModel()
    @State private var showJoinSheet = false
    @State private var accessToDelete: SharedBabyAccess?

    var body: some View {
        List {
            // Generate invite
            Section {
                if let baby = babyVM.selectedBaby {
                    Button {
                        Task {
                            guard let userId = authVM.currentUserId else { return }
                            await vm.generateInvite(for: baby, userId: userId)
                        }
                    } label: {
                        Label("초대 코드 생성", systemImage: "person.badge.plus")
                    }
                    .disabled(vm.isLoading)
                }

                if let invite = vm.generatedInvite {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(invite.code)
                                .font(.system(.title, design: .monospaced).weight(.bold))
                                .foregroundStyle(.primary)
                            Spacer()
                            Button {
                                UIPasteboard.general.string = invite.code
                                vm.message = "코드가 복사되었습니다"
                            } label: {
                                Image(systemName: "doc.on.doc")
                            }
                            ShareLink(item: "올케어 가족 초대 코드: \(invite.code)") {
                                Image(systemName: "square.and.arrow.up")
                            }
                        }
                        Text("\(invite.babyName)의 공동 양육자로 초대합니다")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("7일 후 만료")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text("초대하기")
            } footer: {
                Text("초대 코드는 7일간 유효합니다. 코드를 받은 가족은 아기의 기록을 함께 확인하고 추가할 수 있습니다.")
            }

            // Join with code
            Section {
                Button {
                    showJoinSheet = true
                } label: {
                    Label("초대 코드 입력", systemImage: "ticket")
                }
            } header: {
                Text("참여하기")
            }

            // Shared babies
            if !vm.sharedAccess.isEmpty {
                Section("공유된 아기") {
                    ForEach(vm.sharedAccess) { access in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(access.babyName)
                                    .font(.body.weight(.medium))
                                Text("공동 양육자")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                accessToDelete = access
                            } label: {
                                Label("삭제", systemImage: "trash")
                            }
                        }
                    }
                }
            }

            if let message = vm.message {
                Section {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
            }
        }
        .navigationTitle("가족 공유")
        .task {
            guard let userId = authVM.currentUserId else { return }
            await vm.fetchSharedAccess(userId: userId)
        }
        .sheet(isPresented: $showJoinSheet) {
            JoinFamilySheet(onJoin: { access in
                vm.sharedAccess.append(access)
            })
            .presentationDetents([.medium])
        }
        .onChange(of: vm.sharedAccess.count) { _, _ in
            guard let userId = authVM.currentUserId else { return }
            Task { await babyVM.loadBabies(userId: userId) }
        }
        .confirmationDialog(
            "공유 해제",
            isPresented: Binding(
                get: { accessToDelete != nil },
                set: { if !$0 { accessToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("공유 해제", role: .destructive) {
                guard let access = accessToDelete,
                      let userId = authVM.currentUserId else { return }
                Task {
                    await vm.removeSharedAccess(access: access, userId: userId)
                    accessToDelete = nil
                }
            }
            Button("취소", role: .cancel) { accessToDelete = nil }
        } message: {
            if let access = accessToDelete {
                Text("\(access.babyName)의 공유를 해제하면 해당 가족 구성원이 더 이상 기록을 볼 수 없습니다.")
            }
        }
    }
}

// MARK: - Join Family Sheet

private struct JoinFamilySheet: View {
    @Environment(AuthViewModel.self) private var authVM
    @Environment(BabyViewModel.self) private var babyVM
    @Environment(\.dismiss) private var dismiss
    let onJoin: (SharedBabyAccess) -> Void

    @State private var vm = FamilySharingViewModel()
    @State private var code = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "ticket.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.blue)

                Text("초대 코드를 입력하세요")
                    .font(.title3.weight(.bold))

                TextField("6자리 코드", text: $code)
                    .font(.system(.title2, design: .monospaced))
                    .textCase(.uppercase)
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 40)
                    .onChange(of: code) { _, newValue in
                        code = String(newValue.uppercased().prefix(6))
                    }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Button {
                    Task { await joinFamily() }
                } label: {
                    Text(isLoading ? "참여 중..." : "참여하기")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(code.count != 6 || isLoading)
                .padding(.horizontal, 40)

                Spacer()
            }
            .padding(.top, 32)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
            }
        }
    }

    private func joinFamily() async {
        guard let userId = authVM.currentUserId else { return }
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil

        do {
            let access = try await vm.joinFamily(code: code, userId: userId)
            onJoin(access)
            dismiss()
        } catch let error as FamilySharingError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "참여에 실패했습니다."
        }
    }
}

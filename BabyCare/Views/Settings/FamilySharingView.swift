import SwiftUI

struct FamilySharingView: View {
    @Environment(AuthViewModel.self) private var authVM
    @Environment(BabyViewModel.self) private var babyVM

    @State private var inviteCode = ""
    @State private var generatedInvite: FamilyInvite?
    @State private var sharedAccess: [SharedBabyAccess] = []
    @State private var isLoading = false
    @State private var message: String?
    @State private var showJoinSheet = false

    private let firestoreService = FirestoreService.shared

    var body: some View {
        List {
            // Generate invite
            Section {
                if let baby = babyVM.selectedBaby {
                    Button {
                        Task { await generateInvite(for: baby) }
                    } label: {
                        Label("초대 코드 생성", systemImage: "person.badge.plus")
                    }
                    .disabled(isLoading)
                }

                if let invite = generatedInvite {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(invite.code)
                                .font(.system(.title, design: .monospaced).weight(.bold))
                                .foregroundStyle(.primary)
                            Spacer()
                            Button {
                                UIPasteboard.general.string = invite.code
                                message = "코드가 복사되었습니다"
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
                Text("초대 코드를 공유하면 상대방이 같은 아기의 기록을 함께 볼 수 있습니다.")
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
            if !sharedAccess.isEmpty {
                Section("공유된 아기") {
                    ForEach(sharedAccess) { access in
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
                                Task {
                                    guard let userId = authVM.currentUserId else { return }
                                    try? await firestoreService.removeSharedAccess(accessId: access.id, userId: userId)
                                    sharedAccess.removeAll { $0.id == access.id }
                                }
                            } label: {
                                Label("삭제", systemImage: "trash")
                            }
                        }
                    }
                }
            }

            if let message {
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
            sharedAccess = (try? await firestoreService.fetchSharedAccess(userId: userId)) ?? []
        }
        .sheet(isPresented: $showJoinSheet) {
            JoinFamilySheet(onJoin: { access in
                sharedAccess.append(access)
            })
            .presentationDetents([.medium])
        }
    }

    private func generateInvite(for baby: Baby) async {
        guard let userId = authVM.currentUserId else { return }
        isLoading = true
        defer { isLoading = false }

        let invite = FamilyInvite(
            ownerUserId: userId,
            babyId: baby.id,
            babyName: baby.name
        )
        do {
            try await firestoreService.saveInvite(invite)
            generatedInvite = invite
        } catch {
            message = "초대 코드 생성에 실패했습니다."
        }
    }
}

// MARK: - Join Family Sheet

private struct JoinFamilySheet: View {
    @Environment(AuthViewModel.self) private var authVM
    @Environment(BabyViewModel.self) private var babyVM
    @Environment(\.dismiss) private var dismiss
    let onJoin: (SharedBabyAccess) -> Void

    @State private var code = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let firestoreService = FirestoreService.shared

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
            guard let invite = try await firestoreService.findInviteByCode(code) else {
                errorMessage = "유효하지 않은 코드입니다."
                return
            }
            guard invite.expiresAt > Date() else {
                errorMessage = "만료된 초대 코드입니다."
                return
            }
            guard invite.ownerUserId != userId else {
                errorMessage = "본인의 초대 코드는 사용할 수 없습니다."
                return
            }

            // 중복 참여 검사
            let isDuplicate = try await firestoreService.checkDuplicateAccess(
                userId: userId,
                ownerUserId: invite.ownerUserId,
                babyId: invite.babyId
            )
            guard !isDuplicate else {
                errorMessage = "이미 참여한 아기입니다."
                return
            }

            let access = SharedBabyAccess(
                ownerUserId: invite.ownerUserId,
                babyId: invite.babyId,
                babyName: invite.babyName
            )
            try await firestoreService.saveSharedAccess(access, userId: userId)
            // markInviteUsed 실패해도 참여 성공 처리
            try? await firestoreService.markInviteUsed(invite.id)
            onJoin(access)
            await babyVM.loadBabies(userId: userId)
            dismiss()
        } catch {
            errorMessage = "참여에 실패했습니다."
        }
    }
}

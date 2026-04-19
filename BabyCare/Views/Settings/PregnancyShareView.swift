import SwiftUI

/// 임신 데이터 파트너 공유 설정.
/// 읽기 전용 접근 (sharedWith 배열에 파트너 UID 추가).
struct PregnancyShareView: View {
    @Environment(AuthViewModel.self) private var authVM
    @Environment(PregnancyViewModel.self) private var pregnancyVM

    @State private var partnerEmail = ""
    @State private var isSharing = false
    @State private var message: String?
    @State private var showRemoveAlert = false
    @State private var uidToRemove: String?

    var body: some View {
        List {
            if let pregnancy = pregnancyVM.activePregnancy {
                // 현재 공유 상태
                Section {
                    if let shared = pregnancy.sharedWith, !shared.isEmpty {
                        ForEach(shared, id: \.self) { uid in
                            HStack {
                                Image(systemName: "person.fill")
                                    .foregroundStyle(.secondary)
                                Text(uid.prefix(8) + "...")
                                    .font(.body.monospaced())
                                Spacer()
                                Button(role: .destructive) {
                                    uidToRemove = uid
                                    showRemoveAlert = true
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.red.opacity(0.7))
                                }
                            }
                        }
                    } else {
                        Text(NSLocalizedString("pregnancy.share.noPartner", comment: ""))
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text(NSLocalizedString("pregnancy.share.current", comment: ""))
                } footer: {
                    Text(NSLocalizedString("pregnancy.share.readOnly", comment: ""))
                }

                // 파트너 추가 (이메일로 UID 조회 → sharedWith 추가)
                Section {
                    TextField(NSLocalizedString("pregnancy.share.emailPlaceholder", comment: ""), text: $partnerEmail)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)

                    Button {
                        Task { await shareWithPartner() }
                    } label: {
                        Label(NSLocalizedString("pregnancy.share.invite", comment: ""), systemImage: "paperplane.fill")
                    }
                    .disabled(partnerEmail.isEmpty || isSharing)
                } header: {
                    Text(NSLocalizedString("pregnancy.share.add", comment: ""))
                }

                if let msg = message {
                    Section {
                        Text(msg)
                            .font(.caption)
                            .foregroundStyle(msg.contains("실패") ? .red : .green)
                    }
                }
            } else {
                Section {
                    Text(NSLocalizedString("pregnancy.share.noPregnancy", comment: ""))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(NSLocalizedString("pregnancy.share.title", comment: ""))
        .alert(NSLocalizedString("pregnancy.share.removeTitle", comment: ""), isPresented: $showRemoveAlert) {
            Button(NSLocalizedString("pregnancy.share.removeConfirm", comment: ""), role: .destructive) {
                if let uid = uidToRemove {
                    Task { await removePartner(uid: uid) }
                }
            }
            Button(NSLocalizedString("pregnancy.share.cancel", comment: ""), role: .cancel) {}
        } message: {
            Text(NSLocalizedString("pregnancy.share.removeMessage", comment: ""))
        }
    }

    private func shareWithPartner() async {
        guard let userId = authVM.currentUserId else { return }
        isSharing = true
        defer { isSharing = false }
        do {
            try await pregnancyVM.addPartner(email: partnerEmail, userId: userId)
            message = NSLocalizedString("pregnancy.share.success", comment: "")
            partnerEmail = ""
        } catch {
            message = NSLocalizedString("pregnancy.share.failed", comment: "") + ": \(error.localizedDescription)"
        }
    }

    private func removePartner(uid: String) async {
        guard let userId = authVM.currentUserId else { return }
        do {
            try await pregnancyVM.removePartner(uid: uid, userId: userId)
        } catch {
            message = NSLocalizedString("pregnancy.share.removeFailed", comment: "") + ": \(error.localizedDescription)"
        }
    }
}

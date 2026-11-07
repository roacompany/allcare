import SwiftUI

// MARK: - Forgot Password Sheet

struct ForgotPasswordSheet: View {
    let authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var resetEmail = ""
    @State private var isSent = false
    @State private var isSending = false
    /// 보내기가 실패한 까닭. 있으면 칸 아래에 띄우고 「보냈다」로 안 넘어간다.
    @State private var failure: String?

    private var accentPurple: Color {
        colorScheme == .dark
            ? Color(red: 0.7, green: 0.6, blue: 1.0)
            : Color(red: 0.6, green: 0.5, blue: 0.85)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                // 자판이 올라온 채 오류 줄까지 뜨면 높이가 모자라 위 안내 문장이 잘렸다 → 넘치면 스크롤한다
                ScrollView {
                    VStack(spacing: 28) {
                        VStack(spacing: 10) {
                            Image(systemName: "key.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(accentPurple)
                                .padding(.top, 8)

                            Text("비밀번호 재설정")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(.primary)

                            Text("가입하신 이메일 주소를 입력하시면\n재설정 링크를 보내드립니다.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }

                        if isSent {
                            VStack(spacing: 10) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 36))
                                    .foregroundStyle(.green)

                                Text("재설정 링크를 발송했습니다.")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.primary)

                                Text("이메일을 확인해 주세요.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(20)
                            .background(.green.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        } else {
                            VStack(alignment: .leading, spacing: 10) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Label("이메일", systemImage: "envelope.fill")
                                        .font(.footnote.weight(.semibold))
                                        .foregroundStyle(.secondary)

                                    TextField("이메일 주소를 입력하세요", text: $resetEmail)
                                        .keyboardType(.emailAddress)
                                        .textContentType(.emailAddress)
                                        .autocapitalization(.none)
                                        .autocorrectionDisabled()
                                        .padding(14)
                                        .background(Color(.tertiarySystemBackground))
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color(.separator), lineWidth: 1.5)
                                        )
                                        .onChange(of: resetEmail) { failure = nil }
                                }

                                // 로그인 화면 오류 줄과 같은 모양
                                if let failure {
                                    HStack(spacing: DS2.Spacing.sm) {
                                        Image(systemName: "exclamationmark.circle.fill")
                                            .foregroundStyle(DS2.Color.danger)
                                        Text(failure)
                                            .font(DS2.Font.caption)
                                            .foregroundStyle(DS2.Color.danger)
                                        Spacer()
                                    }
                                    .padding(DS2.Spacing.md)
                                    .background(
                                        DS2.Color.danger.opacity(0.12),
                                        in: RoundedRectangle(cornerRadius: DS2.Radius.sm, style: .continuous)
                                    )
                                }
                            }

                            Button {
                                Task { await sendReset() }
                            } label: {
                                Text("재설정 링크 보내기")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(16)
                                    .background(
                                        LinearGradient(
                                            colors: [Color(red: 0.85, green: 0.6, blue: 0.9), Color(red: 0.6, green: 0.5, blue: 0.9)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .disabled(resetEmail.isEmpty || isSending)
                            .opacity(resetEmail.isEmpty ? 0.6 : 1.0)
                        }
                    }
                    .padding(28)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") { dismiss() }
                        .foregroundStyle(accentPurple)
                }
            }
        }
    }

    /// 성공일 때만 「발송했습니다」로 넘어간다. 실패하면 까닭을 이 창에 띄운다.
    private func sendReset() async {
        isSending = true
        failure = await authVM.sendPasswordReset(to: resetEmail)
        isSending = false
        isSent = failure == nil
    }
}

#Preview {
    LoginView()
        .environment(AuthViewModel())
}

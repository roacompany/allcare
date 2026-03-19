import SwiftUI

// MARK: - Forgot Password Sheet

struct ForgotPasswordSheet: View {
    let authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var resetEmail = ""
    @State private var isSent = false

    private var accentPurple: Color {
        colorScheme == .dark
            ? Color(red: 0.7, green: 0.6, blue: 1.0)
            : Color(red: 0.6, green: 0.5, blue: 0.85)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

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
                        }

                        Button {
                            let previousEmail = authVM.email
                            authVM.email = resetEmail
                            Task {
                                await authVM.resetPassword()
                                authVM.email = previousEmail
                                isSent = true
                            }
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
                        .disabled(resetEmail.isEmpty)
                        .opacity(resetEmail.isEmpty ? 0.6 : 1.0)
                    }

                    Spacer()
                }
                .padding(28)
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
}

#Preview {
    LoginView()
        .environment(AuthViewModel())
}

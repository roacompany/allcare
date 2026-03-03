import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @Environment(AuthViewModel.self) private var authVM
    @Environment(\.colorScheme) private var colorScheme
    @State private var showForgotPassword = false
    @State private var navigateToSignUp = false

    private var bgGradient: [Color] {
        colorScheme == .dark
            ? [Color(red: 0.12, green: 0.1, blue: 0.18), Color(red: 0.1, green: 0.12, blue: 0.2)]
            : [Color(red: 0.98, green: 0.94, blue: 0.96), Color(red: 0.94, green: 0.96, blue: 1.0)]
    }

    private var accentPurple: Color {
        colorScheme == .dark
            ? Color(red: 0.7, green: 0.6, blue: 1.0)
            : Color(red: 0.6, green: 0.5, blue: 0.85)
    }

    private var fieldBorder: Color {
        colorScheme == .dark
            ? Color(.systemGray4)
            : Color(red: 0.85, green: 0.8, blue: 0.95)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: bgGradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 32) {
                        // Logo / Header
                        VStack(spacing: 12) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 56))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color(red: 1.0, green: 0.6, blue: 0.7), Color(red: 0.8, green: 0.6, blue: 1.0)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .padding(.top, 48)

                            Text("BabyCare")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary)

                            Text("우리 아이의 소중한 순간을 기록하세요")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }

                        // Form Card
                        VStack(spacing: 20) {
                            // Error message
                            if let error = authVM.errorMessage {
                                HStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.circle.fill")
                                        .foregroundStyle(.red)
                                    Text(error)
                                        .font(.footnote)
                                        .foregroundStyle(.red)
                                    Spacer()
                                }
                                .padding(12)
                                .background(.red.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }

                            // Email field
                            VStack(alignment: .leading, spacing: 6) {
                                Label("이메일", systemImage: "envelope.fill")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.secondary)

                                @Bindable var vm = authVM
                                TextField("이메일 주소를 입력하세요", text: $vm.email)
                                    .keyboardType(.emailAddress)
                                    .textContentType(.emailAddress)
                                    .autocapitalization(.none)
                                    .autocorrectionDisabled()
                                    .padding(14)
                                    .background(Color(.tertiarySystemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(fieldBorder, lineWidth: 1.5)
                                    )
                            }

                            // Password field
                            VStack(alignment: .leading, spacing: 6) {
                                Label("비밀번호", systemImage: "lock.fill")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.secondary)

                                @Bindable var vm = authVM
                                SecureField("비밀번호를 입력하세요", text: $vm.password)
                                    .textContentType(.password)
                                    .padding(14)
                                    .background(Color(.tertiarySystemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(fieldBorder, lineWidth: 1.5)
                                    )
                            }

                            // Forgot password
                            HStack {
                                Spacer()
                                Button("비밀번호를 잊으셨나요?") {
                                    showForgotPassword = true
                                }
                                .font(.footnote)
                                .foregroundStyle(accentPurple)
                            }

                            // Sign in button
                            Button {
                                Task { await authVM.signIn() }
                            } label: {
                                HStack(spacing: 8) {
                                    if authVM.isLoading {
                                        ProgressView()
                                            .tint(.white)
                                            .scaleEffect(0.85)
                                    }
                                    Text(authVM.isLoading ? "로그인 중..." : "로그인")
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(16)
                                .background(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.85, green: 0.6, blue: 0.9),
                                            Color(red: 0.6, green: 0.5, blue: 0.9)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .shadow(color: accentPurple.opacity(0.35), radius: 8, y: 4)
                            }
                            .disabled(authVM.isLoading || authVM.email.isEmpty || authVM.password.isEmpty)
                            .opacity(authVM.email.isEmpty || authVM.password.isEmpty ? 0.6 : 1.0)
                            .animation(.easeInOut(duration: 0.2), value: authVM.isLoading)
                        }
                        .padding(24)
                        .background(Color(.secondarySystemBackground).opacity(0.85))
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.06), radius: 16, y: 6)
                        .padding(.horizontal, 20)

                        // Apple Sign In
                        VStack(spacing: 12) {
                            HStack {
                                Rectangle().fill(Color(.separator)).frame(height: 0.5)
                                Text("또는")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Rectangle().fill(Color(.separator)).frame(height: 0.5)
                            }
                            .padding(.horizontal, 40)

                            SignInWithAppleButton(.signIn) { request in
                                guard let hashedNonce = authVM.prepareAppleNonce() else { return }
                                request.requestedScopes = [.fullName, .email]
                                request.nonce = hashedNonce
                            } onCompletion: { result in
                                Task { await authVM.handleAppleSignIn(result: result) }
                            }
                            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                            .frame(height: 50)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .padding(.horizontal, 20)
                        }

                        // Sign up link
                        VStack(spacing: 4) {
                            Text("아직 계정이 없으신가요?")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            NavigationLink(destination: SignUpView()) {
                                Text("회원가입하기")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(accentPurple)
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 12)
                                    .background(accentPurple.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationBarHidden(true)
            .onDisappear {
                authVM.clearForm()
            }
            .sheet(isPresented: $showForgotPassword) {
                ForgotPasswordSheet(authVM: authVM)
            }
        }
    }
}

// MARK: - Forgot Password Sheet

private struct ForgotPasswordSheet: View {
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

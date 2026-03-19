import SwiftUI
import AuthenticationServices

struct SignUpView: View {
    @Environment(AuthViewModel.self) private var authVM
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    private var bgGradient: [Color] {
        colorScheme == .dark
            ? [Color(red: 0.1, green: 0.1, blue: 0.18), Color(red: 0.12, green: 0.1, blue: 0.2)]
            : [Color(red: 0.94, green: 0.97, blue: 1.0), Color(red: 0.98, green: 0.93, blue: 0.97)]
    }

    private var accentPurple: Color {
        colorScheme == .dark
            ? Color(red: 0.7, green: 0.6, blue: 1.0)
            : Color(red: 0.55, green: 0.5, blue: 0.85)
    }

    private var fieldBorder: Color {
        colorScheme == .dark
            ? Color(.systemGray4)
            : Color(red: 0.8, green: 0.8, blue: 0.95)
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: bgGradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {
                    // Header
                    VStack(spacing: 10) {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .font(.system(size: 52))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(red: 0.5, green: 0.7, blue: 1.0), Color(red: 0.8, green: 0.55, blue: 0.95)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .padding(.top, 16)

                        Text("회원가입")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)

                        Text("계정을 만들어 아이의 성장을 기록하세요")
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

                        @Bindable var vm = authVM

                        // Name field
                        AuthFormField(label: "이름", icon: "person.fill", borderColor: fieldBorder) {
                            TextField("이름을 입력하세요", text: $vm.displayName)
                                .textContentType(.name)
                                .autocorrectionDisabled()
                        }

                        // Email field
                        AuthFormField(label: "이메일", icon: "envelope.fill", borderColor: fieldBorder) {
                            TextField("이메일 주소를 입력하세요", text: $vm.email)
                                .keyboardType(.emailAddress)
                                .textContentType(.emailAddress)
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                        }

                        // Password field
                        AuthFormField(label: "비밀번호", icon: "lock.fill", borderColor: fieldBorder) {
                            SecureField("비밀번호를 입력하세요", text: $vm.password)
                                .textContentType(.newPassword)
                        }

                        // Confirm password field
                        VStack(alignment: .leading, spacing: 6) {
                            AuthFormField(label: "비밀번호 확인", icon: "lock.rotation", borderColor: fieldBorder) {
                                SecureField("비밀번호를 다시 입력하세요", text: $vm.confirmPassword)
                                    .textContentType(.newPassword)
                            }

                            // Password match indicator
                            if !vm.confirmPassword.isEmpty {
                                let matches = vm.password == vm.confirmPassword
                                HStack(spacing: 4) {
                                    Image(systemName: matches ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .font(.caption)
                                        .foregroundStyle(matches ? .green : .red)
                                    Text(matches ? "비밀번호가 일치합니다" : "비밀번호가 일치하지 않습니다")
                                        .font(.caption)
                                        .foregroundStyle(matches ? .green : .red)
                                }
                                .padding(.leading, 4)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                                .animation(.easeInOut(duration: 0.2), value: vm.confirmPassword)
                            }
                        }

                        // Password strength hint
                        if !vm.password.isEmpty {
                            PasswordStrengthView(password: vm.password)
                                .transition(.opacity)
                                .animation(.easeInOut(duration: 0.25), value: vm.password.isEmpty)
                        }

                        // Sign up button
                        Button {
                            Task { await authVM.signUp() }
                        } label: {
                            HStack(spacing: 8) {
                                if authVM.isLoading {
                                    ProgressView()
                                        .tint(.white)
                                        .scaleEffect(0.85)
                                }
                                Text(authVM.isLoading ? "가입 중..." : "회원가입")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(16)
                            .background(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.5, green: 0.65, blue: 0.95),
                                        Color(red: 0.7, green: 0.5, blue: 0.9)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .shadow(color: accentPurple.opacity(0.35), radius: 8, y: 4)
                        }
                        .disabled(authVM.isLoading || !isFormValid)
                        .opacity(!isFormValid ? 0.6 : 1.0)
                        .animation(.easeInOut(duration: 0.2), value: authVM.isLoading)

                        // Terms notice
                        VStack(spacing: 2) {
                            Text("가입하시면 아래에 동의하시는 것으로 간주됩니다.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 4) {
                                Link("서비스 이용약관", destination: URL(string: "https://roacompany.github.io/allcare/terms.html")!)
                                    .font(.caption2)
                                Text("및")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Link("개인정보 처리방침", destination: URL(string: "https://roacompany.github.io/allcare/privacy.html")!)
                                    .font(.caption2)
                            }
                        }
                        .multilineTextAlignment(.center)
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
                        .padding(.horizontal, 20)

                        SignInWithAppleButton(.signUp) { request in
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

                    // Login link
                    HStack(spacing: 4) {
                        Text("이미 계정이 있으신가요?")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Button("로그인") {
                            dismiss()
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(accentPurple)
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    authVM.clearForm()
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("로그인")
                            .font(.subheadline)
                    }
                    .foregroundStyle(accentPurple)
                }
            }
        }
        .onDisappear {
            if !authVM.isLoading {
                authVM.clearForm()
            }
        }
    }

    private var isFormValid: Bool {
        !authVM.displayName.isEmpty &&
        !authVM.email.isEmpty &&
        authVM.password.count >= 6 &&
        authVM.password == authVM.confirmPassword
    }
}

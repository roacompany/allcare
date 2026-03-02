import SwiftUI

struct SignUpView: View {
    @Environment(AuthViewModel.self) private var authVM
    @Environment(\.dismiss) private var dismiss

    // Local confirm password state to mirror authVM.confirmPassword
    // using @Bindable for two-way binding with @Observable

    var body: some View {
        ZStack {
            // Pastel background gradient
            LinearGradient(
                colors: [
                    Color(red: 0.94, green: 0.97, blue: 1.0),
                    Color(red: 0.98, green: 0.93, blue: 0.97)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
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
                            .foregroundColor(Color(red: 0.35, green: 0.3, blue: 0.5))

                        Text("계정을 만들어 아이의 성장을 기록하세요")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    // Form Card
                    VStack(spacing: 20) {
                        // Error message
                        if let error = authVM.errorMessage {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundColor(Color(red: 1.0, green: 0.4, blue: 0.4))
                                Text(error)
                                    .font(.footnote)
                                    .foregroundColor(Color(red: 0.7, green: 0.2, blue: 0.2))
                                Spacer()
                            }
                            .padding(12)
                            .background(Color(red: 1.0, green: 0.92, blue: 0.92))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }

                        @Bindable var vm = authVM

                        // Name field
                        FormField(
                            label: "이름",
                            icon: "person.fill",
                            placeholder: "이름을 입력하세요"
                        ) {
                            TextField("이름을 입력하세요", text: $vm.displayName)
                                .textContentType(.name)
                                .autocorrectionDisabled()
                        }

                        // Email field
                        FormField(
                            label: "이메일",
                            icon: "envelope.fill",
                            placeholder: "이메일 주소를 입력하세요"
                        ) {
                            TextField("이메일 주소를 입력하세요", text: $vm.email)
                                .keyboardType(.emailAddress)
                                .textContentType(.emailAddress)
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                        }

                        // Password field
                        FormField(
                            label: "비밀번호",
                            icon: "lock.fill",
                            placeholder: "비밀번호를 입력하세요"
                        ) {
                            SecureField("비밀번호를 입력하세요", text: $vm.password)
                                .textContentType(.newPassword)
                        }

                        // Confirm password field
                        VStack(alignment: .leading, spacing: 6) {
                            FormField(
                                label: "비밀번호 확인",
                                icon: "lock.rotation",
                                placeholder: "비밀번호를 다시 입력하세요"
                            ) {
                                SecureField("비밀번호를 다시 입력하세요", text: $vm.confirmPassword)
                                    .textContentType(.newPassword)
                            }

                            // Password match indicator
                            if !vm.confirmPassword.isEmpty {
                                let matches = vm.password == vm.confirmPassword
                                HStack(spacing: 4) {
                                    Image(systemName: matches ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .font(.caption)
                                        .foregroundColor(matches ? Color(red: 0.3, green: 0.75, blue: 0.5) : Color(red: 0.9, green: 0.35, blue: 0.35))
                                    Text(matches ? "비밀번호가 일치합니다" : "비밀번호가 일치하지 않습니다")
                                        .font(.caption)
                                        .foregroundColor(matches ? Color(red: 0.3, green: 0.65, blue: 0.45) : Color(red: 0.8, green: 0.3, blue: 0.3))
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
                                    .foregroundColor(.white)
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
                            .shadow(color: Color(red: 0.55, green: 0.5, blue: 0.85).opacity(0.35), radius: 8, y: 4)
                        }
                        .disabled(authVM.isLoading || !isFormValid)
                        .opacity(!isFormValid ? 0.6 : 1.0)
                        .animation(.easeInOut(duration: 0.2), value: authVM.isLoading)

                        // Terms notice
                        Text("가입하시면 서비스 이용약관 및 개인정보 처리방침에 동의하시는 것으로 간주됩니다.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(24)
                    .background(Color.white.opacity(0.7))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: .black.opacity(0.06), radius: 16, y: 6)
                    .padding(.horizontal, 20)

                    // Login link
                    HStack(spacing: 4) {
                        Text("이미 계정이 있으신가요?")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Button("로그인") {
                            dismiss()
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Color(red: 0.55, green: 0.5, blue: 0.85))
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
                    .foregroundColor(Color(red: 0.55, green: 0.5, blue: 0.85))
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

// MARK: - FormField

private struct FormField<Content: View>: View {
    let label: String
    let icon: String
    let placeholder: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(label, systemImage: icon)
                .font(.footnote.weight(.semibold))
                .foregroundColor(Color(red: 0.5, green: 0.4, blue: 0.65))

            content()
                .padding(14)
                .background(Color.white.opacity(0.85))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(red: 0.8, green: 0.8, blue: 0.95), lineWidth: 1.5)
                )
        }
    }
}

// MARK: - Password Strength View

private struct PasswordStrengthView: View {
    let password: String

    private var strength: PasswordStrength {
        if password.count < 6 { return .weak }
        let hasUpper = password.contains(where: \.isUppercase)
        let hasNumber = password.contains(where: \.isNumber)
        let hasSpecial = password.contains(where: { "!@#$%^&*()_+-=[]{}|;':\",./<>?".contains($0) })
        let score = [hasUpper, hasNumber, hasSpecial].filter { $0 }.count
        if password.count >= 12 && score >= 2 { return .strong }
        if password.count >= 8 && score >= 1 { return .medium }
        return .weak
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(index < strength.filledBars ? strength.color : Color(white: 0.9))
                        .frame(height: 4)
                        .animation(.easeInOut(duration: 0.25), value: strength.filledBars)
                }
            }

            Text("비밀번호 강도: \(strength.label)")
                .font(.caption2)
                .foregroundColor(strength.color)
        }
        .padding(.horizontal, 2)
    }

    private enum PasswordStrength {
        case weak, medium, strong

        var filledBars: Int {
            switch self {
            case .weak: return 1
            case .medium: return 2
            case .strong: return 3
            }
        }

        var color: Color {
            switch self {
            case .weak: return Color(red: 0.9, green: 0.35, blue: 0.35)
            case .medium: return Color(red: 0.95, green: 0.7, blue: 0.2)
            case .strong: return Color(red: 0.3, green: 0.75, blue: 0.5)
            }
        }

        var label: String {
            switch self {
            case .weak: return "약함"
            case .medium: return "보통"
            case .strong: return "강함"
            }
        }
    }
}

#Preview {
    NavigationStack {
        SignUpView()
            .environment(AuthViewModel())
    }
}

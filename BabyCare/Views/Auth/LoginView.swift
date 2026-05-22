import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @Environment(AuthViewModel.self) private var authVM
    @Environment(\.colorScheme) private var colorScheme
    @State private var showForgotPassword = false
    @State private var navigateToSignUp = false

    // MARK: - V1 컬러 (기존)
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

    @ViewBuilder
    var body: some View {
        if FeatureFlags.designSystemV2Preview {
            loginV2
        } else {
            loginV1
        }
    }

    // MARK: - V2 (DS2 토큰 기반)
    private var loginV2: some View {
        NavigationStack {
            ZStack {
                DS2.Color.surfacePrimary.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: DS2.Spacing.xl) {
                        // Brand
                        VStack(spacing: DS2.Spacing.md) {
                            ZStack {
                                Circle()
                                    .fill(DS2.Color.accent.opacity(0.12))
                                    .frame(width: 96, height: 96)
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 44))
                                    .foregroundStyle(DS2.Color.accent)
                            }
                            .padding(.top, DS2.Spacing.xxl)

                            VStack(spacing: DS2.Spacing.xs) {
                                Text("BabyCare")
                                    .font(DS2.Font.largeTitle)
                                Text("우리 아이의 소중한 순간을 기록하세요")
                                    .font(DS2.Font.subheadline)
                                    .foregroundStyle(DS2.Color.textSecondary)
                                    .multilineTextAlignment(.center)
                            }
                        }

                        // Form Card
                        DS2Card {
                            VStack(spacing: DS2.Spacing.lg) {
                                if let error = authVM.errorMessage {
                                    HStack(spacing: DS2.Spacing.sm) {
                                        Image(systemName: "exclamationmark.circle.fill")
                                            .foregroundStyle(DS2.Color.danger)
                                        Text(error)
                                            .font(DS2.Font.caption)
                                            .foregroundStyle(DS2.Color.danger)
                                        Spacer()
                                    }
                                    .padding(DS2.Spacing.md)
                                    .background(DS2.Color.danger.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: DS2.Radius.sm))
                                }

                                // Email
                                ds2InputField(
                                    label: "이메일",
                                    icon: "envelope.fill",
                                    placeholder: "이메일 주소를 입력하세요",
                                    isSecure: false
                                )

                                // Password
                                ds2InputField(
                                    label: "비밀번호",
                                    icon: "lock.fill",
                                    placeholder: "비밀번호를 입력하세요",
                                    isSecure: true
                                )

                                // Forgot password
                                HStack {
                                    Spacer()
                                    Button("비밀번호를 잊으셨나요?") {
                                        showForgotPassword = true
                                    }
                                    .font(DS2.Font.caption)
                                    .foregroundStyle(DS2.Color.accent)
                                }

                                // Sign in button
                                DS2Button(
                                    authVM.isLoading ? "로그인 중..." : "로그인",
                                    icon: authVM.isLoading ? nil : "arrow.right.circle.fill",
                                    style: .primary
                                ) {
                                    Task { await authVM.signIn() }
                                }
                                .disabled(authVM.isLoading || authVM.email.isEmpty || authVM.password.isEmpty)
                                .opacity(authVM.email.isEmpty || authVM.password.isEmpty ? 0.6 : 1.0)
                                .animation(.easeInOut(duration: 0.2), value: authVM.isLoading)
                            }
                        }
                        .padding(.horizontal, DS2.Spacing.lg)
                        .ds2Shadow(.md)

                        // Divider + Apple Sign In
                        VStack(spacing: DS2.Spacing.md) {
                            HStack(spacing: DS2.Spacing.md) {
                                Rectangle().fill(.quaternary).frame(height: 0.5)
                                Text("또는")
                                    .font(DS2.Font.caption)
                                    .foregroundStyle(DS2.Color.textSecondary)
                                Rectangle().fill(.quaternary).frame(height: 0.5)
                            }
                            .padding(.horizontal, DS2.Spacing.xxl)

                            SignInWithAppleButton(.signIn) { request in
                                guard let hashedNonce = authVM.prepareAppleNonce() else { return }
                                request.requestedScopes = [.fullName, .email]
                                request.nonce = hashedNonce
                            } onCompletion: { result in
                                Task { await authVM.handleAppleSignIn(result: result) }
                            }
                            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                            .frame(height: 48)
                            .clipShape(RoundedRectangle(cornerRadius: DS2.Radius.md, style: .continuous))
                            .padding(.horizontal, DS2.Spacing.lg)
                        }

                        // Sign up link
                        VStack(spacing: DS2.Spacing.xs) {
                            Text("아직 계정이 없으신가요?")
                                .font(DS2.Font.subheadline)
                                .foregroundStyle(DS2.Color.textSecondary)
                            NavigationLink(destination: SignUpView()) {
                                Text("회원가입하기")
                                    .font(DS2.Font.subheadline.weight(.semibold))
                                    .foregroundStyle(DS2.Color.accent)
                                    .padding(.vertical, DS2.Spacing.xs)
                                    .padding(.horizontal, DS2.Spacing.md)
                                    .background(DS2.Color.accent.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.bottom, DS2.Spacing.xxl)
                    }
                }
            }
            .navigationBarHidden(true)
            .onDisappear { authVM.clearForm() }
            .sheet(isPresented: $showForgotPassword) {
                ForgotPasswordSheet(authVM: authVM)
            }
        }
    }

    /// DS2 토큰 기반 인풋 필드 (이메일/비밀번호 공통).
    private func ds2InputField(label: String, icon: String, placeholder: String, isSecure: Bool) -> some View {
        VStack(alignment: .leading, spacing: DS2.Spacing.xs) {
            Label(label, systemImage: icon)
                .font(DS2.Font.caption.weight(.semibold))
                .foregroundStyle(DS2.Color.textSecondary)

            @Bindable var vm = authVM
            Group {
                if isSecure {
                    SecureField(placeholder, text: $vm.password)
                        .textContentType(.password)
                } else {
                    TextField(placeholder, text: $vm.email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                }
            }
            .padding(DS2.Spacing.md)
            .background(DS2.Color.surfacePrimary, in: RoundedRectangle(cornerRadius: DS2.Radius.sm, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS2.Radius.sm, style: .continuous)
                    .stroke(.quaternary, lineWidth: 1)
            )
        }
    }

    // MARK: - V1 (기존, FeatureFlag off 시 fallback)
    private var loginV1: some View {
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
                                .font(.largeTitle.weight(.bold))
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

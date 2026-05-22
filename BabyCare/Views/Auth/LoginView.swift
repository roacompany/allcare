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

    // MARK: - V2 (Glassmorphism — gradient bg + ultraThinMaterial card)
    private var v2BgGradient: [Color] {
        colorScheme == .dark
            ? [Color(red: 0.12, green: 0.10, blue: 0.22), Color(red: 0.18, green: 0.14, blue: 0.30)]
            : [Color(red: 1.00, green: 0.88, blue: 0.92), Color(red: 0.90, green: 0.88, blue: 1.00)]
    }

    private var v2BrandGradient: [Color] {
        [Color(red: 1.0, green: 0.55, blue: 0.70), Color(red: 0.65, green: 0.55, blue: 0.95)]
    }

    private var loginV2: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: v2BgGradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()

                // Subtle decorative orbs (glass blurred)
                v2DecorativeOrbs

                ScrollView {
                    VStack(spacing: DS2.Spacing.xxl) {
                        // Brand
                        VStack(spacing: DS2.Spacing.md) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 64))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: v2BrandGradient,
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .padding(.top, DS2.Spacing.xxl + DS2.Spacing.xl)

                            VStack(spacing: DS2.Spacing.xs) {
                                Text("BabyCare")
                                    .font(DS2.Font.largeTitle)
                                    .foregroundStyle(.primary)
                                Text("우리 아이의 소중한 순간을 기록하세요")
                                    .font(DS2.Font.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                        }

                        // Form Card — frosted glass
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
                                .background(
                                    DS2.Color.danger.opacity(0.12),
                                    in: RoundedRectangle(cornerRadius: DS2.Radius.sm, style: .continuous)
                                )
                            }

                            glassInputField(
                                label: "이메일",
                                icon: "envelope.fill",
                                placeholder: "이메일 주소를 입력하세요",
                                isSecure: false
                            )
                            glassInputField(
                                label: "비밀번호",
                                icon: "lock.fill",
                                placeholder: "비밀번호를 입력하세요",
                                isSecure: true
                            )

                            HStack {
                                Spacer()
                                Button("비밀번호를 잊으셨나요?") {
                                    showForgotPassword = true
                                }
                                .font(DS2.Font.caption)
                                .foregroundStyle(v2AccentColor)
                            }

                            Button {
                                Task { await authVM.signIn() }
                            } label: {
                                HStack(spacing: DS2.Spacing.sm) {
                                    if authVM.isLoading {
                                        ProgressView()
                                            .tint(.white)
                                            .scaleEffect(0.85)
                                    }
                                    Text(authVM.isLoading ? "로그인 중..." : "로그인")
                                        .font(DS2.Font.headline)
                                        .foregroundStyle(.white)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, DS2.Spacing.md + 2)
                                .background(
                                    LinearGradient(
                                        colors: v2BrandGradient,
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: DS2.Radius.md, style: .continuous))
                                .ds2Shadow(.md)
                            }
                            .buttonStyle(.plain)
                            .disabled(authVM.isLoading || authVM.email.isEmpty || authVM.password.isEmpty)
                            .opacity(authVM.email.isEmpty || authVM.password.isEmpty ? 0.6 : 1.0)
                            .animation(.easeInOut(duration: 0.2), value: authVM.isLoading)
                        }
                        .padding(DS2.Spacing.xl)
                        .background(
                            .ultraThinMaterial,
                            in: RoundedRectangle(cornerRadius: DS2.Radius.lg, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: DS2.Radius.lg, style: .continuous)
                                .stroke(.white.opacity(colorScheme == .dark ? 0.10 : 0.50), lineWidth: 0.5)
                        )
                        .ds2Shadow(.lg)
                        .padding(.horizontal, DS2.Spacing.lg)

                        // Divider + Apple Sign In
                        VStack(spacing: DS2.Spacing.md) {
                            HStack(spacing: DS2.Spacing.md) {
                                Rectangle().fill(.quaternary).frame(height: 0.5)
                                Text("또는")
                                    .font(DS2.Font.caption)
                                    .foregroundStyle(.secondary)
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
                            .frame(height: 50)
                            .clipShape(RoundedRectangle(cornerRadius: DS2.Radius.md, style: .continuous))
                            .padding(.horizontal, DS2.Spacing.lg)
                        }

                        // Sign up
                        VStack(spacing: DS2.Spacing.xs) {
                            Text("아직 계정이 없으신가요?")
                                .font(DS2.Font.subheadline)
                                .foregroundStyle(.secondary)
                            NavigationLink(destination: SignUpView()) {
                                Text("회원가입하기")
                                    .font(DS2.Font.subheadline.weight(.semibold))
                                    .foregroundStyle(v2AccentColor)
                                    .padding(.vertical, DS2.Spacing.xs + 2)
                                    .padding(.horizontal, DS2.Spacing.md)
                                    .background(
                                        .ultraThinMaterial,
                                        in: Capsule()
                                    )
                                    .overlay(
                                        Capsule().stroke(v2AccentColor.opacity(0.3), lineWidth: 0.5)
                                    )
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

    /// Glass 인풋 필드 — .thinMaterial 배경 + 미세 border.
    private func glassInputField(label: String, icon: String, placeholder: String, isSecure: Bool) -> some View {
        VStack(alignment: .leading, spacing: DS2.Spacing.xs + 2) {
            Label(label, systemImage: icon)
                .font(DS2.Font.caption.weight(.semibold))
                .foregroundStyle(.secondary)

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
            .padding(DS2.Spacing.md + 2)
            .background(
                .thinMaterial,
                in: RoundedRectangle(cornerRadius: DS2.Radius.sm, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS2.Radius.sm, style: .continuous)
                    .stroke(.white.opacity(colorScheme == .dark ? 0.10 : 0.40), lineWidth: 0.5)
            )
        }
    }

    /// Glass 분위기 강조용 blurred orb (배경 장식). 다크모드 자동 대응.
    private var v2DecorativeOrbs: some View {
        ZStack {
            Circle()
                .fill(Color(red: 1.0, green: 0.55, blue: 0.75))
                .frame(width: 240, height: 240)
                .blur(radius: 80)
                .opacity(colorScheme == .dark ? 0.30 : 0.55)
                .offset(x: -120, y: -260)

            Circle()
                .fill(Color(red: 0.65, green: 0.55, blue: 0.95))
                .frame(width: 280, height: 280)
                .blur(radius: 100)
                .opacity(colorScheme == .dark ? 0.30 : 0.50)
                .offset(x: 140, y: 280)
        }
        .allowsHitTesting(false)
    }

    private var v2AccentColor: Color {
        colorScheme == .dark
            ? Color(red: 1.0, green: 0.65, blue: 0.80)
            : Color(red: 0.80, green: 0.45, blue: 0.70)
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

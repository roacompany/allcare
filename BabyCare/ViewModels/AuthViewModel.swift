import Foundation
import FirebaseAuth
import AuthenticationServices

@MainActor @Observable
final class AuthViewModel {
    var email = ""
    var password = ""
    var confirmPassword = ""
    var displayName = ""
    var isLoading = false
    var errorMessage: String?
    var isAuthenticated = false
    var currentUserId: String?

    private let authService = AuthService.shared
    nonisolated(unsafe) private var listenerHandle: AuthStateDidChangeListenerHandle?

    init() {
        // 초기값 동기화
        isAuthenticated = authService.isAuthenticated
        currentUserId = authService.userId

        // Auth state 실시간 리스너
        listenerHandle = authService.addStateListener { [weak self] user in
            let isAuth = user != nil
            let uid = user?.uid
            Task { @MainActor [weak self] in
                self?.isAuthenticated = isAuth
                self?.currentUserId = uid
            }
        }
    }

    deinit {
        if let handle = listenerHandle {
            authService.removeStateListener(handle)
        }
    }

    // MARK: - Validation

    var isSignInFormValid: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty && !password.isEmpty
    }

    var isSignUpFormValid: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty
        && password.count >= 6
        && password == confirmPassword
    }

    // MARK: - Actions

    func signUp() async {
        guard isSignUpFormValid else {
            if email.isEmpty { errorMessage = "이메일을 입력해주세요." }
            else if password.count < 6 { errorMessage = "비밀번호는 6자 이상이어야 합니다." }
            else if password != confirmPassword { errorMessage = "비밀번호가 일치하지 않습니다." }
            return
        }

        isLoading = true
        errorMessage = nil
        do {
            _ = try await authService.signUp(email: email, password: password)
            if !displayName.isEmpty {
                try await authService.updateDisplayName(displayName)
            }
        } catch {
            errorMessage = mapAuthError(error)
        }
        isLoading = false
    }

    func signIn() async {
        guard isSignInFormValid else {
            errorMessage = "이메일과 비밀번호를 입력해주세요."
            return
        }

        isLoading = true
        errorMessage = nil
        do {
            _ = try await authService.signIn(email: email, password: password)
        } catch {
            errorMessage = mapAuthError(error)
        }
        isLoading = false
    }

    func signOut() {
        do {
            try authService.signOut()
            clearForm()
        } catch {
            errorMessage = "로그아웃에 실패했습니다."
        }
    }

    func resetPassword() async {
        guard !email.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "이메일을 입력해주세요."
            return
        }

        isLoading = true
        errorMessage = nil
        do {
            try await authService.resetPassword(email: email)
            errorMessage = nil
        } catch {
            errorMessage = mapAuthError(error)
        }
        isLoading = false
    }

    // MARK: - Apple Sign In

    private(set) var currentNonce: String?

    func handleAppleSignIn(result: Result<ASAuthorization, Error>) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        switch result {
        case .success(let authorization):
            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let idTokenData = appleIDCredential.identityToken,
                  let idToken = String(data: idTokenData, encoding: .utf8),
                  let nonce = currentNonce else {
                errorMessage = "Apple 로그인 정보를 가져올 수 없습니다."
                return
            }
            do {
                let user = try await authService.signInWithApple(idToken: idToken, nonce: nonce)
                // Apple에서 이름을 주면 Firebase profile에 저장
                if let fullName = appleIDCredential.fullName {
                    let name = [fullName.familyName, fullName.givenName].compactMap { $0 }.joined()
                    if !name.isEmpty {
                        try? await authService.updateDisplayName(name)
                    }
                }
                _ = user
            } catch {
                errorMessage = mapAuthError(error)
            }
        case .failure(let error):
            // 사용자가 취소한 경우 에러 표시하지 않음
            if (error as NSError).code != ASAuthorizationError.canceled.rawValue {
                errorMessage = "Apple 로그인에 실패했습니다."
            }
        }
    }

    func prepareAppleNonce() -> String? {
        guard let nonce = try? AuthService.randomNonceString() else {
            errorMessage = "인증 준비에 실패했습니다. 다시 시도해주세요."
            return nil
        }
        currentNonce = nonce
        return AuthService.sha256(nonce)
    }

    func clearForm() {
        email = ""
        password = ""
        confirmPassword = ""
        displayName = ""
        errorMessage = nil
    }

    private func mapAuthError(_ error: Error) -> String {
        let nsError = error as NSError
        switch nsError.code {
        case AuthErrorCode.emailAlreadyInUse.rawValue:
            return "이미 사용 중인 이메일입니다."
        case AuthErrorCode.invalidEmail.rawValue:
            return "올바른 이메일 형식이 아닙니다."
        case AuthErrorCode.weakPassword.rawValue:
            return "비밀번호가 너무 약합니다."
        case AuthErrorCode.wrongPassword.rawValue:
            return "비밀번호가 올바르지 않습니다."
        case AuthErrorCode.userNotFound.rawValue:
            return "등록되지 않은 이메일입니다."
        case AuthErrorCode.networkError.rawValue:
            return "네트워크 오류가 발생했습니다. 연결을 확인해주세요."
        default:
            return "오류가 발생했습니다: \(error.localizedDescription)"
        }
    }
}

import Foundation
import FirebaseAuth

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

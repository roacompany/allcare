import Foundation
import FirebaseAuth
import FirebaseCore
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
    private let migration: AuthMigrationProviding
    private let storageService: StorageServiceProviding
    nonisolated(unsafe) private var listenerHandle: AuthStateDidChangeListenerHandle?

    init(
        migration: AuthMigrationProviding = FirestoreService.shared,
        storageService: StorageServiceProviding = StorageService.shared
    ) {
        self.migration = migration
        self.storageService = storageService
        // UI 테스트 모드: Firebase 없이 인증 완료 상태로 시작
        if CommandLine.arguments.contains("UI_TESTING") {
            isAuthenticated = true
            currentUserId = "ui-test-user"
            return
        }

        // Firebase가 초기화된 경우에만 Auth 접근
        if FirebaseApp.app() != nil {
            isAuthenticated = authService.isAuthenticated
            currentUserId = authService.userId
        }

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
            if email.isEmpty {
                errorMessage = "이메일을 입력해주세요."
            } else if password.count < 6 {
                errorMessage = "비밀번호는 6자 이상이어야 합니다."
            } else if password != confirmPassword {
                errorMessage = "비밀번호가 일치하지 않습니다."
            }
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
        Task {
            await FCMTokenService.shared.deleteToken()
        }
        do {
            try authService.signOut()
            clearForm()
        } catch {
            errorMessage = "로그아웃에 실패했습니다."
        }
    }

    func deleteAccount() async {
        isLoading = true
        errorMessage = nil
        do {
            // 1. Auth 계정 먼저 삭제 (requiresRecentLogin 에러 발생 가능)
            //    실패하면 데이터 손실 없이 중단됨
            let userId = currentUserId
            try await authService.deleteAccount()
            // 2. Auth 삭제 성공 후 데이터 정리 (실패해도 계정은 이미 삭제됨)
            await FCMTokenService.shared.deleteToken()
            if let userId {
                do {
                    try await deleteUserData(userId: userId)
                } catch {
                    logSilent("계정 데이터 정리 실패 (Auth는 이미 삭제됨)", error: error, logger: AppLogger.auth)
                }
                // Storage 사진 정리 (PII 잔존 방지) — Firestore 정리와 독립 시도
                do {
                    try await storageService.deleteUserStorage(userId: userId)
                } catch {
                    logSilent("계정 Storage 사진 정리 실패 (Auth는 이미 삭제됨)", error: error, logger: AppLogger.storage)
                }
            }
            // Auth state listener가 isAuthenticated=false로 전환 → ContentView가 LoginView 표시
            // 하지만 싱글톤 ViewModel들의 상태는 남아있으므로 명시적 초기화
            clearForm()
            isAuthenticated = false
            currentUserId = nil
        } catch {
            let nsError = error as NSError
            if nsError.code == AuthErrorCode.requiresRecentLogin.rawValue {
                errorMessage = "보안을 위해 재로그인이 필요합니다. 로그아웃 후 다시 로그인해주세요."
            } else {
                logSilent("계정 삭제 실패", error: error, logger: AppLogger.auth)
                errorMessage = "계정 삭제에 실패했습니다. 잠시 후 다시 시도해 주세요."
            }
        }
        isLoading = false
    }

    /// 계정 + 모든 서브컬렉션 데이터 삭제. 실제 batch 로직은 FirestoreService+User 에 위치.
    private func deleteUserData(userId: String) async throws {
        try await migration.deleteAllUserData(userId: userId)
    }

    /// familySharing(구형) → sharedAccess(신형) 인라인 마이그레이션. 실제 batch 로직은 FirestoreService+User 에 위치.
    func migrateFamilySharingIfNeeded(userId: String) async {
        await migration.migrateFamilySharingIfNeeded(userId: userId)
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
                        do {
                            try await authService.updateDisplayName(name)
                        } catch {
                            logSilent("Apple 가입 표시명 저장 실패", error: error, logger: AppLogger.auth)
                        }
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
            logSilent("auth 오류 (미분류 코드 \(nsError.code))", error: error, logger: AppLogger.auth)
            return "로그인 처리 중 문제가 생겼어요. 잠시 후 다시 시도해 주세요."
        }
    }
}

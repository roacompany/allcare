import Foundation
import FirebaseAuth
import AuthenticationServices
import CryptoKit

/// Firebase Auth 래퍼. ViewModel이 아닌 Service이므로 상태를 직접 노출하지 않고,
/// AuthViewModel이 auth state listener를 관리한다.
final class AuthService: Sendable {
    static let shared = AuthService()

    private init() {}

    var currentUser: User? {
        Auth.auth().currentUser
    }

    var userId: String? {
        currentUser?.uid
    }

    var isAuthenticated: Bool {
        currentUser != nil
    }

    func signUp(email: String, password: String) async throws -> User {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        return result.user
    }

    func signIn(email: String, password: String) async throws -> User {
        let result = try await Auth.auth().signIn(withEmail: email, password: password)
        return result.user
    }

    func signOut() throws {
        try Auth.auth().signOut()
    }

    func resetPassword(email: String) async throws {
        try await Auth.auth().sendPasswordReset(withEmail: email)
    }

    /// 로그인한 사람의 Firebase ID 토큰. 웹 관리자 서버가 이걸로 관리자인지 확인한다.
    func idToken() async throws -> String {
        guard let user = currentUser else { throw AuthError.notSignedIn }
        return try await user.getIDToken()
    }

    func updateDisplayName(_ name: String) async throws {
        guard let user = currentUser else { return }
        let changeRequest = user.createProfileChangeRequest()
        changeRequest.displayName = name
        try await changeRequest.commitChanges()
    }

    func deleteAccount() async throws {
        try await currentUser?.delete()
    }

    func addStateListener(_ handler: @escaping @Sendable (User?) -> Void) -> AuthStateDidChangeListenerHandle {
        Auth.auth().addStateDidChangeListener { _, user in
            handler(user)
        }
    }

    func removeStateListener(_ handle: AuthStateDidChangeListenerHandle) {
        Auth.auth().removeStateDidChangeListener(handle)
    }

    // MARK: - Apple Sign In

    func signInWithApple(idToken: String, nonce: String) async throws -> User {
        let credential = OAuthProvider.appleCredential(
            withIDToken: idToken,
            rawNonce: nonce,
            fullName: nil
        )
        let result = try await Auth.auth().signIn(with: credential)
        return result.user
    }

    enum AuthError: LocalizedError {
        case nonceGenerationFailed(OSStatus)
        case notSignedIn

        var errorDescription: String? {
            switch self {
            case .nonceGenerationFailed(let status):
                return "Nonce 생성에 실패했습니다. (OSStatus: \(status))"
            case .notSignedIn:
                return "로그인이 필요합니다."
            }
        }
    }

    static func randomNonceString(length: Int = 32) throws -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        guard errorCode == errSecSuccess else {
            throw AuthError.nonceGenerationFailed(errorCode)
        }
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    static func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
}

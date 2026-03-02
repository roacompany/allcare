import Foundation
import FirebaseAuth

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
}

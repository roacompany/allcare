import FirebaseFirestore
import Foundation

extension FirestoreService: AccountDataErasing {
    /// RED 판: 고치기 전 지우기(deleteAllUserData) 그대로.
    func eraseAllUserData(userId: String) async throws {
        try await deleteAllUserData(userId: userId)
    }
}

import Foundation
import FirebaseFirestore

extension FirestoreService {
    /// 단일 경로: users/{userId}/badges/{badgeId}
    /// 신규 저장 시 true, 이미 존재 시 false 반환
    @discardableResult
    func saveBadge(_ badge: Badge, userId: String) async throws -> Bool {
        let ref = db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.badges)
            .document(badge.id)

        let snapshot = try await ref.getDocument()
        guard !snapshot.exists else { return false }

        try ref.setData(from: badge)
        return true
    }

    func fetchBadges(userId: String) async throws -> [Badge] {
        let snapshot = try await db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.badges)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: Badge.self) }
    }

    func badgeExists(userId: String, badgeId: String) async throws -> Bool {
        let ref = db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.badges)
            .document(badgeId)
        let snapshot = try await ref.getDocument()
        return snapshot.exists
    }
}

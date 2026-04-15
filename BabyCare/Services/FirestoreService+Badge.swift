import Foundation
import FirebaseFirestore

extension FirestoreService {
    /// 단일 경로: users/{userId}/badges/{badgeId}
    /// 중복 방지: 기존 문서 있으면 덮어쓰지 않음 (no-op)
    func saveBadge(_ badge: Badge, userId: String) async throws {
        let ref = db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.badges)
            .document(badge.id)

        let snapshot = try await ref.getDocument()
        guard !snapshot.exists else { return }

        try ref.setData(from: badge)
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

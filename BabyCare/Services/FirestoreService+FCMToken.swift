import FirebaseFirestore
import Foundation

/// FCMTokenService 가 의존하는 FCM 토큰 R/W narrow protocol (ISP).
/// 로그인 직후 토큰 등록 / 로그아웃 시 토큰 정리 흐름 단위 테스트 가능.
protocol FCMTokenFirestoreProviding: Sendable {
    func saveFCMToken(userId: String, deviceId: String, token: String) async throws
    func deleteFCMToken(userId: String, deviceId: String) async throws
}

extension FirestoreService: FCMTokenFirestoreProviding {}

extension FirestoreService {
    // MARK: - FCM Token

    /// FCM 토큰 등록 — users/{userId}/fcmTokens/{deviceId} 에 setData.
    /// 동일 deviceId 재호출 시 overwrite (idempotent). updatedAt 은 server timestamp.
    func saveFCMToken(userId: String, deviceId: String, token: String) async throws {
        let ref = db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.fcmTokens)
            .document(deviceId)
        try await ref.setData([
            "token": token,
            "updatedAt": FieldValue.serverTimestamp(),
            "platform": "iOS"
        ])
    }

    /// FCM 토큰 삭제 — 로그아웃 시 현재 디바이스 토큰 정리.
    func deleteFCMToken(userId: String, deviceId: String) async throws {
        let ref = db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.fcmTokens)
            .document(deviceId)
        try await ref.delete()
    }
}

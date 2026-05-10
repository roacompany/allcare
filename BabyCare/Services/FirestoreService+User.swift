import FirebaseFirestore
import Foundation

extension FirestoreService {
    // MARK: - User Metadata

    private static let lastAccessedAtKey = "BabyCare.lastAccessedAt.persistedAt"
    private static let lastAccessedAtThrottleSeconds: TimeInterval = 60 * 60

    /// users/{uid}.lastAccessedAt 갱신. 어드민 "최근 접속일" 표시용.
    /// Firebase Auth metadata.lastSignInTime은 명시적 로그인에만 갱신되어 정확한 활동 추적 불가.
    /// 1시간 throttle로 쓰기 비용 제한.
    func updateLastAccessedAt(userId: String) async {
        if CommandLine.arguments.contains("UI_TESTING") { return }
        let now = Date()
        let lastPersisted = UserDefaults.standard.object(forKey: Self.lastAccessedAtKey) as? Date
        if let lastPersisted, now.timeIntervalSince(lastPersisted) < Self.lastAccessedAtThrottleSeconds {
            return
        }
        do {
            try await db.collection(FirestoreCollections.users)
                .document(userId)
                .setData(["lastAccessedAt": FieldValue.serverTimestamp()], merge: true)
            UserDefaults.standard.set(now, forKey: Self.lastAccessedAtKey)
        } catch {
            Self.logger.warning("updateLastAccessedAt failed: \(error.localizedDescription)")
        }
    }
}

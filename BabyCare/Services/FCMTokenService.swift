import Foundation
import FirebaseAuth
import FirebaseFirestore
import UIKit

@MainActor
final class FCMTokenService {
    static let shared = FCMTokenService()
    private let db = Firestore.firestore()
    private var cachedToken: String?

    private init() {}

    /// FCM 토큰을 Firestore에 저장
    func saveToken(_ token: String) async {
        cachedToken = token
        guard let userId = Auth.auth().currentUser?.uid else { return }

        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        let ref = db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.fcmTokens)
            .document(deviceId)

        do {
            try await ref.setData([
                "token": token,
                "updatedAt": FieldValue.serverTimestamp(),
                "platform": "iOS"
            ])
        } catch {
            print("[FCM] 토큰 저장 실패: \(error.localizedDescription)")
        }
    }

    /// 로그아웃 시 현재 디바이스 토큰 삭제
    func deleteToken() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        let ref = db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.fcmTokens)
            .document(deviceId)

        do {
            try await ref.delete()
        } catch {
            print("[FCM] 토큰 삭제 실패: \(error.localizedDescription)")
        }
        cachedToken = nil
    }

    /// 캐시된 토큰을 현재 사용자에게 재저장 (로그인 직후)
    func resendCachedToken() async {
        guard let token = cachedToken else { return }
        await saveToken(token)
    }
}

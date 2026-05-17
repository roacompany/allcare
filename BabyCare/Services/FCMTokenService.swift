import Foundation
import FirebaseAuth
import UIKit

@MainActor
final class FCMTokenService {
    static let shared = FCMTokenService()
    private let firestore: FCMTokenFirestoreProviding
    private var cachedToken: String?

    init(firestore: FCMTokenFirestoreProviding = FirestoreService.shared) {
        self.firestore = firestore
    }

    /// FCM 토큰을 Firestore에 저장
    func saveToken(_ token: String) async {
        cachedToken = token
        guard let userId = Auth.auth().currentUser?.uid else { return }

        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        do {
            try await firestore.saveFCMToken(userId: userId, deviceId: deviceId, token: token)
        } catch {
            print("[FCM] 토큰 저장 실패: \(error.localizedDescription)")
        }
    }

    /// 로그아웃 시 현재 디바이스 토큰 삭제
    func deleteToken() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        do {
            try await firestore.deleteFCMToken(userId: userId, deviceId: deviceId)
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

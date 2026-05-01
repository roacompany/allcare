import UIKit
import FirebaseCore
import FirebaseMessaging
import GoogleMobileAds
@preconcurrency import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate, @preconcurrency MessagingDelegate, @preconcurrency UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }

        // MobileAds: 비개인화 광고 (privacy.html "IDFA 미사용" 약속 유지)
        // child-directed는 false — 베이비케어는 App Store "Made for Kids" 카테고리가
        // 아니며(ASC API isOrEverWasMadeForKids=false, kidsAgeBand=null) 부모(성인)
        // 사용자 대상 앱이므로 COPPA 의무 대상이 아니다. true로 설정 시 광고 인벤토리
        // 풀이 ~5-20%로 축소되어 fill rate 저하 → 빈 광고 영역 노출 원인.
        MobileAds.shared.requestConfiguration.tagForChildDirectedTreatment = false
        MobileAds.shared.requestConfiguration.publisherPrivacyPersonalizationState = .disabled
        MobileAds.shared.start(completionHandler: nil)

        // Analytics 옵트아웃 상태 반영
        AnalyticsService.shared.configure()

        // FCM 델리게이트
        Messaging.messaging().delegate = self

        // 알림 센터 델리게이트 (포그라운드 표시용)
        UNUserNotificationCenter.current().delegate = self

        // 원격 알림 등록
        application.registerForRemoteNotifications()

        return true
    }

    // MARK: - APNs Token

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("[APNs] 등록 실패: \(error.localizedDescription)")
    }

    // MARK: - MessagingDelegate

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }
        print("[FCM] 토큰 수신: \(token.prefix(20))...")

        Task { @MainActor in
            await FCMTokenService.shared.saveToken(token)
        }

        // 전체 발송용 토픽 구독
        Messaging.messaging().subscribe(toTopic: "all_users")
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// 포그라운드에서 알림 수신 시 배너 표시
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    /// 알림 탭 핸들링
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        Task { @MainActor in
            NotificationRouter.shared.handleNotification(userInfo: userInfo)
        }
        completionHandler()
    }
}

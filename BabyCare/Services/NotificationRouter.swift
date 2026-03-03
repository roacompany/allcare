import Foundation

/// 알림 탭 시 딥링크 라우팅
@MainActor
final class NotificationRouter: ObservableObject {
    static let shared = NotificationRouter()

    enum Destination {
        case dashboard
        case announcements
    }

    @Published var pendingDestination: Destination?

    private init() {}

    func handleNotification(userInfo: [AnyHashable: Any]) {
        guard let type = userInfo["type"] as? String else { return }

        switch type {
        case "announcement":
            pendingDestination = .announcements
        default:
            pendingDestination = .dashboard
        }
    }

    func consumeDestination() -> Destination? {
        let dest = pendingDestination
        pendingDestination = nil
        return dest
    }
}

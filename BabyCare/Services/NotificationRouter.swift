import Foundation

/// 알림 탭 시 딥링크 라우팅
@MainActor
final class NotificationRouter: ObservableObject {
    static let shared = NotificationRouter()

    enum Destination {
        case dashboard
        case announcements
        case reorderProduct(productId: String, coupangURL: String?)
    }

    @Published var pendingDestination: Destination?

    private init() {}

    func handleNotification(userInfo: [AnyHashable: Any]) {
        guard let type = userInfo["type"] as? String else { return }

        switch type {
        case "announcement":
            pendingDestination = .announcements
        case "reorder":
            let productId = userInfo["productId"] as? String ?? ""
            let coupangURLString = userInfo["coupangURL"] as? String
            let coupangURL = (coupangURLString?.isEmpty == false) ? coupangURLString : nil
            pendingDestination = .reorderProduct(productId: productId, coupangURL: coupangURL)
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

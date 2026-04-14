import Foundation

@MainActor @Observable
final class NotificationSettingsViewModel {
    func cancelActivityReminder(type: Activity.ActivityType) {
        NotificationService.shared.cancelActivityReminder(type: type)
    }
}

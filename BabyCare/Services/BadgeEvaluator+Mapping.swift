import Foundation

extension BadgeEvaluator {
    /// Activity.ActivityType → Event.Kind 매핑 (배지 대상이 아닌 타입은 nil)
    static func eventKind(for type: Activity.ActivityType) -> Event.Kind? {
        switch type {
        case .feedingBreast, .feedingBottle, .feedingSolid, .feedingSnack:
            return .feedingLogged
        case .sleep:
            return .sleepLogged
        case .diaperWet, .diaperDirty, .diaperBoth:
            return .diaperLogged
        case .temperature, .medication, .bath:
            return nil
        @unknown default:
            return nil
        }
    }
}

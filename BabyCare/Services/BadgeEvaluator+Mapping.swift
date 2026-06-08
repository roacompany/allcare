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
        case .temperature, .medication, .bath, .feedingPumping:
            return nil   // 유축은 배지 대상 아님 (명시 — default 의존 금지, spec §5.1/§6)
        @unknown default:
            return nil
        }
    }
}

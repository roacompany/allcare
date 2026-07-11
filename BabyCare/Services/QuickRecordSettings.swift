import Foundation

enum QuickRecordSettings {
    nonisolated(unsafe) private static let defaults = UserDefaults.standard
    private static let key = "quickRecordEnabledTypes"

    // .unknown(forward-compat 센티넬)은 사용자 기록 picker에 노출 금지
    static let allAvailableTypes: [Activity.ActivityType] = Activity.ActivityType.allCases.filter { $0 != .unknown }

    // 야간 고빈도 우선: 수유(모유/분유)·수면·기저귀·체온. 저빈도(간식/유축/목욕)는 사용자 추가 or ＋런처(전체).
    static let defaultTypes: [Activity.ActivityType] = [
        .feedingBreast, .feedingBottle, .sleep,
        .diaperWet, .diaperDirty, .diaperBoth,
        .temperature, .feedingSolid, .medication
    ]

    static var enabledTypes: [Activity.ActivityType] {
        get {
            guard let data = defaults.data(forKey: key),
                  let rawValues = try? JSONDecoder().decode([String].self, from: data) else {
                return defaultTypes
            }
            // known(rawValue:)로 센티넬 "unknown" 부활 차단 (init?(rawValue:)는 커스텀 decoder 우회)
            let types = rawValues.compactMap { Activity.ActivityType.known(rawValue: $0) }
            return types.isEmpty ? defaultTypes : types
        }
        set {
            let rawValues = newValue.map(\.rawValue)
            if let data = try? JSONEncoder().encode(rawValues) {
                defaults.set(data, forKey: key)
            }
        }
    }
}

import Foundation

enum QuickRecordSettings {
    nonisolated(unsafe) private static let defaults = UserDefaults.standard
    private static let key = "quickRecordEnabledTypes"

    static let allAvailableTypes: [Activity.ActivityType] = Activity.ActivityType.allCases

    static let defaultTypes: [Activity.ActivityType] = [
        .feedingBreast, .feedingSolid, .feedingSnack,
        .diaperWet, .diaperDirty, .diaperBoth,
        .bath, .medication
    ]

    static var enabledTypes: [Activity.ActivityType] {
        get {
            guard let data = defaults.data(forKey: key),
                  let rawValues = try? JSONDecoder().decode([String].self, from: data) else {
                return defaultTypes
            }
            let types = rawValues.compactMap { Activity.ActivityType(rawValue: $0) }
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

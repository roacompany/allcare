import SwiftUI
import UIKit

/// 앱 전체 다크 모드 설정 관리
@MainActor
@Observable
final class ThemeManager {
    static let shared = ThemeManager()

    enum AppearanceMode: String, CaseIterable {
        case system = "시스템 설정"
        case light = "라이트"
        case dark = "다크"

        var userInterfaceStyle: UIUserInterfaceStyle {
            switch self {
            case .system: .unspecified
            case .light:  .light
            case .dark:   .dark
            }
        }
    }

    private let key = "app_appearance_mode"

    var currentMode: AppearanceMode {
        didSet {
            UserDefaults.standard.set(currentMode.rawValue, forKey: key)
            applyAppearance()
        }
    }

    private init() {
        if let saved = UserDefaults.standard.string(forKey: key),
           let mode = AppearanceMode(rawValue: saved) {
            currentMode = mode
        } else {
            currentMode = .system
        }
    }

    func applyAppearance() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        for window in windowScene.windows {
            window.overrideUserInterfaceStyle = currentMode.userInterfaceStyle
        }
    }
}

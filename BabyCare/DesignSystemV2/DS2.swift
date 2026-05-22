import SwiftUI

/// 디자인 시스템 V2 (Preview)
///
/// 기존 `AppColors` / `DesignSystem.generated` 와 독립한 폐기 가능 namespace.
/// FeatureFlag `designSystemV2Preview` 가 ON 일 때만 Showcase 화면 노출.
///
/// 정책:
/// - 기존 AppColors 18 Dynamic Color를 wrapping (브랜드 자산 보존)
/// - Spacing 8pt grid, Radius 3-step, Font 10-step
/// - 채택 시 점진 마이그레이션, 폐기 시 namespace 전체 삭제 (영향 0)
enum DS2 {

    // MARK: - Color
    enum Color {
        // Surface
        static let surfacePrimary = SwiftUI.Color("backgroundColor")
        static let surfaceSecondary = SwiftUI.Color("cardBackground")

        // Text
        static let textPrimary = SwiftUI.Color.primary
        static let textSecondary = SwiftUI.Color.secondary
        static let textOnAccent = SwiftUI.Color.white

        // Brand
        static let accent = SwiftUI.Color("primaryAccent")

        // Activity (re-export AppColors)
        static let feeding = AppColors.feedingColor
        static let sleep = AppColors.sleepColor
        static let diaper = AppColors.diaperColor
        static let solid = AppColors.solidColor
        static let bath = AppColors.bathColor
        static let temperature = AppColors.temperatureColor
        static let medication = AppColors.medicationColor

        // Semantic
        static let success = AppColors.successColor
        static let warning = AppColors.warmOrangeColor
        static let danger = AppColors.coralColor
        static let info = AppColors.skyBlueColor

        // Tint — Pastel backgrounds
        static let tintPink = AppColors.pastelPink
        static let tintBlue = AppColors.pastelBlue
        static let tintMint = AppColors.pastelMint
        static let tintYellow = AppColors.pastelYellow
        static let tintPurple = AppColors.pastelPurple
        static let tintOrange = AppColors.pastelOrange
    }

    // MARK: - Spacing (8pt grid)
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    // MARK: - Radius
    enum Radius {
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
    }

    // MARK: - Font (Dynamic Type 우선)
    enum Font {
        static let largeTitle = SwiftUI.Font.largeTitle.weight(.bold)
        static let title = SwiftUI.Font.title.weight(.semibold)
        static let title2 = SwiftUI.Font.title2.weight(.semibold)
        static let title3 = SwiftUI.Font.title3.weight(.semibold)
        static let headline = SwiftUI.Font.headline
        static let body = SwiftUI.Font.body
        static let callout = SwiftUI.Font.callout
        static let subheadline = SwiftUI.Font.subheadline
        static let caption = SwiftUI.Font.caption
        static let caption2 = SwiftUI.Font.caption2
    }

    // MARK: - Shadow
    struct Shadow {
        let color: SwiftUI.Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat

        static let sm = Shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
        static let md = Shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
        static let lg = Shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 8)
    }
}

// MARK: - View modifier
extension View {
    /// DS2 토큰 기반 그림자 적용.
    func ds2Shadow(_ shadow: DS2.Shadow) -> some View {
        self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
}

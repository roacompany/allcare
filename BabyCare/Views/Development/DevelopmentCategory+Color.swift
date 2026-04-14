import SwiftUI

extension DevelopmentCategory {
    var color: Color {
        switch self {
        case .play: AppColors.feedingColor
        case .sleep: AppColors.sleepColor
        case .mentalCare: AppColors.softPurpleColor
        case .insight: AppColors.indigoColor
        }
    }
}

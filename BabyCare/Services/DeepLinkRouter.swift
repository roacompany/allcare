import Foundation

/// 위젯 → 앱 딥링크 라우팅.
/// URL 스킴: `babycare://`
enum DeepLinkRouter {

    enum Destination: Equatable {
        /// RecordingView 시트 열기 (카테고리 선택 없음)
        case record
        /// RecordingView → 특정 카테고리 프리셋
        case recordCategory(ActivityCategory)
        /// 빠른 저장 (시트 없이 즉시 기록)
        case quickSave(QuickSaveType)
        /// 홈 탭 — 「오늘 요약」 위젯 · 잠금 화면 한 줄 · 임신 위젯(임신 화면이 꺼져 있다)
        case home
        /// 건강 › 성장기록 — 성장 백분위 위젯
        case growth

        enum ActivityCategory: String {
            case feeding, diaper, sleep
        }

        enum QuickSaveType: String {
            case feedingBreast
            case diaperWet
        }

        /// 기록 시트를 열 때 미리 고를 칸(`.recordCategory` 만 — 나머지는 칸을 고르지 않는다).
        var recordingCategory: Activity.ActivityCategory? {
            guard case .recordCategory(let category) = self else { return nil }
            switch category {
            case .feeding: return .feeding
            case .sleep: return .sleep
            case .diaper: return .diaper
            }
        }
    }

    /// URL → Destination 파싱
    static func destination(from url: URL) -> Destination? {
        guard url.scheme == "babycare" else { return nil }

        let host = url.host() ?? ""
        let pathComponents = url.pathComponents.filter { $0 != "/" }

        switch host {
        case "record":
            if let category = pathComponents.first,
               let actCat = Destination.ActivityCategory(rawValue: category) {
                return .recordCategory(actCat)
            }
            return .record

        case "quicksave":
            if let typeStr = pathComponents.first,
               let quickType = Destination.QuickSaveType(rawValue: typeStr) {
                return .quickSave(quickType)
            }
            return nil

        case "dashboard":
            return .home

        case "health":
            return pathComponents.first == "growth" ? .growth : nil

        case "pregnancy":
            // 임신 화면은 꺼져 있다(FeatureFlags.pregnancyModeEnabled) — 홈으로(홈에 임신 카드가 붙는다)
            return .home

        default:
            return nil
        }
    }
}

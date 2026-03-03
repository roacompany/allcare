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

        enum ActivityCategory: String {
            case feeding, diaper, sleep
        }

        enum QuickSaveType: String {
            case feedingBreast
            case diaperWet
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

        default:
            return nil
        }
    }
}

import Foundation

/// 산전 체크리스트의 주차→삼분기 매핑·완료율·"이번 주 할 일" 요약 (순수·MainActor/Firestore 무의존·테스트 대상).
enum PregnancyChecklistPlanner {

    /// 현재 주차가 속한 체크리스트 카테고리. 1~13=trimester1 / 14~27=trimester2 / 28주+=trimester3.
    /// 주차 미상(nil)·비정상(<1)이면 nil. (체크리스트 카테고리 문자열은 PregnancyChecklistItem.category 와 1:1)
    static func currentTrimesterCategory(forWeek week: Int?) -> String? {
        guard let w = week, w >= 1 else { return nil }
        switch w {
        case 1...13: return "trimester1"
        case 14...27: return "trimester2"
        default: return "trimester3" // 28주 이상(막달 이후 포함)도 3삼분기 과업
        }
    }

    /// 완료율 0...1 (빈 목록 0).
    static func completionRate(_ items: [PregnancyChecklistItem]) -> Double {
        guard !items.isEmpty else { return 0 }
        return Double(items.filter { $0.isCompleted }.count) / Double(items.count)
    }

    /// "이번 주 할 일" 요약 — 현재 삼분기의 미완료 항목(주차 미상이면 전체 미완료)을 order 정렬 후 최대 limit개.
    static func weeklyHighlights(_ items: [PregnancyChecklistItem],
                                 currentWeek: Int?,
                                 limit: Int = 3) -> [PregnancyChecklistItem] {
        let category = currentTrimesterCategory(forWeek: currentWeek)
        let pool = category.map { cat in items.filter { $0.category == cat } } ?? items
        let incomplete = pool
            .filter { !$0.isCompleted }
            .sorted { ($0.order ?? 0) < ($1.order ?? 0) }
        return Array(incomplete.prefix(max(0, limit)))
    }
}

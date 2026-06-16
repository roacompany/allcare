import Foundation

/// 주차별 임신 콘텐츠 1행 (pregnancy-weeks.json 스키마, 4~40주).
struct PregnancyWeekContent: Codable, Hashable, Sendable {
    let week: Int
    let fruitSize: String
    let milestone: String
    let tip: String
    let disclaimerKey: String?
}

/// 주차 콘텐츠 저장소 — 번들 JSON 로드 + "현재 주차 이하 가장 가까운 항목" 매칭.
/// DashboardPregnancyView.currentWeekInfo 로직을 순수·테스트 가능하게 추출.
struct PregnancyWeekContentStore: Sendable {
    let entries: [PregnancyWeekContent]

    /// 현재 주차보다 작거나 같은 가장 가까운 항목. 없으면(주차가 첫 항목 미만) 첫 항목. entries 빈 경우 nil.
    func content(forWeek week: Int) -> PregnancyWeekContent? {
        entries.last(where: { $0.week <= week }) ?? entries.first
    }

    /// 번들 pregnancy-weeks.json 디코드. 실패 시 빈 저장소(렌더는 옵셔널 가드로 안전).
    static func loadBundled() -> PregnancyWeekContentStore {
        guard let url = Bundle.main.url(forResource: "pregnancy-weeks", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let infos = try? JSONDecoder().decode([PregnancyWeekContent].self, from: data) else {
            return PregnancyWeekContentStore(entries: [])
        }
        return PregnancyWeekContentStore(entries: infos)
    }
}

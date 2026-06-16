import Foundation

/// 검진 탭 히어로 카드·폼 프리필을 위한 순수 파생 — PrenatalVisit 목록과 한국 표준 일정 사이.
/// MainActor/Firestore 무의존, 테스트 대상.
enum PrenatalVisitPlanner {

    /// 히어로 "다음 검진": 미완료 방문 중 ①오늘 이후 가장 가까운 예정, 없으면 ②가장 최근 지연(미완료).
    /// 모두 완료/없음이면 nil.
    static func nextRelevantVisit(in visits: [PrenatalVisit],
                                  asOf now: Date = Date(),
                                  calendar: Calendar = .current) -> PrenatalVisit? {
        let today = calendar.startOfDay(for: now)
        let incomplete = visits.filter { !$0.isCompleted }
        let upcoming = incomplete
            .filter { calendar.startOfDay(for: $0.scheduledAt) >= today }
            .min { $0.scheduledAt < $1.scheduledAt }
        if let upcoming { return upcoming }
        return incomplete
            .filter { calendar.startOfDay(for: $0.scheduledAt) < today }
            .max { $0.scheduledAt < $1.scheduledAt }
    }

    /// 표준 검진 항목의 권장 주차 중앙을 LMP 기준 예정일로 변환(폼 프리필 제안). LMP 없으면 nil.
    /// 임신 N주 ≈ LMP + N×7일.
    static func suggestedDate(for item: KoreanPrenatalScheduleItem,
                              lmpDate: Date?,
                              calendar: Calendar = .current) -> Date? {
        guard let lmp = lmpDate else { return nil }
        let midWeek = (item.weekStart + item.weekEnd) / 2
        return calendar.date(byAdding: .day, value: midWeek * 7, to: lmp)
    }
}

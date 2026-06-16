import Foundation

/// 타임라인 노드의 사용자 검진 대비 진행도(완료/누락 배지용).
enum PrenatalNodeProgress: Hashable {
    case done       // 대응 검진을 완료함
    case logged     // 대응 검진이 등록됨(미완료)
    case missed     // 지난 권장창인데 대응 검진 없음
    case upcoming   // 현재·미래 권장창(기존 status dot 사용)
}

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

    /// 표준 검진 항목에 대응하는 사용자 검진을 LMP 주차 환산으로 fuzzy 매칭해 진행도 산출.
    /// 매칭 규칙: 방문 주차 ∈ [weekStart, weekEnd] AND (방문 유형 미지정 또는 visitTypeHint 일치).
    /// LMP 미상이면 매칭 불가 → 지난창은 누락, 그 외 upcoming.
    static func nodeProgress(for item: KoreanPrenatalScheduleItem,
                             visits: [PrenatalVisit],
                             lmpDate: Date?,
                             currentWeek: Int?,
                             calendar: Calendar = .current) -> PrenatalNodeProgress {
        let matching: [PrenatalVisit] = lmpDate.map { lmp in
            visits.filter { visit in
                let week = weeksBetween(lmp, visit.scheduledAt, calendar: calendar)
                guard week >= item.weekStart, week <= item.weekEnd else { return false }
                let type = visit.visitType?.trimmingCharacters(in: .whitespaces) ?? ""
                return type.isEmpty || type == item.visitTypeHint
            }
        } ?? []
        if matching.contains(where: { $0.isCompleted }) { return .done }
        if !matching.isEmpty { return .logged }
        return KoreanPrenatalSchedule.status(for: item, currentWeek: currentWeek) == .past ? .missed : .upcoming
    }

    private static func weeksBetween(_ start: Date, _ end: Date, calendar: Calendar) -> Int {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: start),
                                           to: calendar.startOfDay(for: end)).day ?? 0
        return days / 7
    }
}

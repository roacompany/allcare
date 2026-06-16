import Foundation

/// 여정 "오늘" 섹션의 동적 승격 카드 종류 (SCREENS.md §①여정 2-d).
enum JourneyPromotedCard: Equatable, Sendable {
    /// 임박 산전검진 (isDueSoon). daysUntil = 0 이면 "오늘".
    case upcomingVisit(daysUntil: Int, hospitalName: String?)
    /// 37주+ 진통 타이머 진입 (5-1-1).
    case laborTimer
}

/// 한국 산전검진 마일스톤 (미래 주차 핀, SCREENS.md §①여정 4 / 한국 디테일).
struct PrenatalMilestone: Equatable, Sendable, Identifiable {
    let weekRange: ClosedRange<Int>
    let title: String
    let symbol: String
    var id: Int { weekRange.lowerBound }
}

/// 여정 "오늘"/"미래" 섹션 파생 — 순수(MainActor/Firestore 무의존), 단위 테스트 대상.
struct PregnancyJourneyContent: Sendable {
    let promotedCards: [JourneyPromotedCard]
    let topIncompleteChecklist: [PregnancyChecklistItem]
    let futureMilestones: [PrenatalMilestone]

    /// 한국 표준 산전검진 일정 (주차 범위 → 항목).
    static let koreanPrenatalSchedule: [PrenatalMilestone] = [
        PrenatalMilestone(weekRange: 11...13, title: "1차 기형아 검사 · 목투명대(NT)", symbol: "stethoscope"),
        PrenatalMilestone(weekRange: 15...20, title: "정밀 초음파", symbol: "waveform.path.ecg"),
        PrenatalMilestone(weekRange: 24...28, title: "임신성 당뇨 검사(GTT)", symbol: "drop.fill")
    ]

    private static let laborTimerWeek = 37

    init(currentWeek: Int?,
         checklistItems: [PregnancyChecklistItem],
         prenatalVisits: [PrenatalVisit]) {

        // 동적 승격 카드: 37주+ 진통 타이머가 최우선, 그 다음 임박 검진. 최대 2.
        var cards: [JourneyPromotedCard] = []
        if let week = currentWeek, week >= Self.laborTimerWeek {
            cards.append(.laborTimer)
        }
        let dueSoonVisits = prenatalVisits
            .filter { $0.isDueSoon }
            .sorted { $0.scheduledAt < $1.scheduledAt }
        for visit in dueSoonVisits {
            cards.append(.upcomingVisit(daysUntil: visit.daysUntilScheduled,
                                        hospitalName: visit.hospitalName))
        }
        self.promotedCards = Array(cards.prefix(2))

        // 미완 체크리스트 top-3 (order 오름차순, nil 은 뒤로).
        self.topIncompleteChecklist = checklistItems
            .filter { !$0.isCompleted }
            .sorted { ($0.order ?? Int.max) < ($1.order ?? Int.max) }
            .prefix(3)
            .map { $0 }

        // 미래 검진 마일스톤: 현재 주차가 범위를 완전히 지나지 않은 것만(upperBound >= currentWeek).
        if let week = currentWeek {
            self.futureMilestones = Self.koreanPrenatalSchedule.filter { $0.weekRange.upperBound >= week }
        } else {
            self.futureMilestones = []
        }
    }
}

import Foundation

/// ②기록 허브 "오늘 요약 스트립" 파생 — 오늘 기록한 항목 개수(순수, 테스트 대상).
struct PregnancyTrackingSummary: Sendable {
    let kickCount: Int
    let weightCount: Int
    let symptomCount: Int

    var isEmpty: Bool { kickCount == 0 && weightCount == 0 && symptomCount == 0 }

    init(now: Date,
         kickSessions: [KickSession],
         weightEntries: [PregnancyWeightEntry],
         symptoms: [PregnancySymptom],
         calendar: Calendar = .current) {
        func isToday(_ d: Date) -> Bool { calendar.isDate(d, inSameDayAs: now) }
        self.kickCount = kickSessions.filter { isToday($0.startedAt) }.count
        self.weightCount = weightEntries.filter { isToday($0.measuredAt) }.count
        self.symptomCount = symptoms.filter { isToday($0.occurredAt) }.count
    }
}

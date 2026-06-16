import XCTest
@testable import BabyCare

final class PregnancyTrackingTests: XCTestCase {

    private let cal = Calendar.current

    private func kick(at date: Date) -> KickSession {
        var s = KickSession(pregnancyId: "p1")
        s.startedAt = date
        return s
    }
    private func weight(at date: Date) -> PregnancyWeightEntry {
        PregnancyWeightEntry(pregnancyId: "p1", weight: 60, unit: "kg", measuredAt: date)
    }
    private func symptom(at date: Date) -> PregnancySymptom {
        PregnancySymptom(pregnancyId: "p1", memo: "메모", occurredAt: date)
    }

    func test_summary_countsOnlyToday() {
        let today = Date()
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
        let summary = PregnancyTrackingSummary(
            now: today,
            kickSessions: [kick(at: today), kick(at: yesterday)],
            weightEntries: [weight(at: today)],
            symptoms: [symptom(at: yesterday)]
        )
        XCTAssertEqual(summary.kickCount, 1)
        XCTAssertEqual(summary.weightCount, 1)
        XCTAssertEqual(summary.symptomCount, 0)
    }

    func test_summary_isEmptyWhenNothingToday() {
        let yesterday = cal.date(byAdding: .day, value: -1, to: Date())!
        let summary = PregnancyTrackingSummary(
            now: Date(), kickSessions: [kick(at: yesterday)], weightEntries: [], symptoms: []
        )
        XCTAssertTrue(summary.isEmpty)
    }

    func test_summary_notEmptyWhenAnyToday() {
        let summary = PregnancyTrackingSummary(
            now: Date(), kickSessions: [], weightEntries: [weight(at: Date())], symptoms: []
        )
        XCTAssertFalse(summary.isEmpty)
    }
}

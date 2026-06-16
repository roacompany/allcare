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

    // MARK: - PregnancyVitalEntry (임당 참고 목표선)

    func test_glucose_withinReference_fasting() {
        // 공복 ≤ 95 mg/dL
        XCTAssertTrue(PregnancyVitalEntry.glucoseWithinReference(value: 90, context: .fasting))
        XCTAssertFalse(PregnancyVitalEntry.glucoseWithinReference(value: 100, context: .fasting))
    }

    func test_glucose_withinReference_postMeal1h() {
        // 식후 1시간 ≤ 140
        XCTAssertTrue(PregnancyVitalEntry.glucoseWithinReference(value: 130, context: .postMeal1h))
        XCTAssertFalse(PregnancyVitalEntry.glucoseWithinReference(value: 150, context: .postMeal1h))
    }

    func test_glucose_withinReference_postMeal2h() {
        // 식후 2시간 ≤ 120
        XCTAssertTrue(PregnancyVitalEntry.glucoseWithinReference(value: 110, context: .postMeal2h))
        XCTAssertFalse(PregnancyVitalEntry.glucoseWithinReference(value: 130, context: .postMeal2h))
    }

    @MainActor
    func test_addVitalEntry_persistsAndPrepends() async {
        let mock = MockPregnancyFirestore()
        let vm = PregnancyViewModel(firestoreService: mock)
        vm.activePregnancy = Pregnancy(lmpDate: nil, dueDate: nil, fetusCount: 1, babyNickname: "t")
        await vm.addVitalEntry(
            PregnancyVitalEntry(pregnancyId: "p1", glucose: 90, glucoseContext: "fasting"),
            userId: "u1"
        )
        XCTAssertEqual(mock.saveVitalEntryCalls.count, 1)
        XCTAssertEqual(vm.vitalEntries.first?.glucose, 90)
    }
}

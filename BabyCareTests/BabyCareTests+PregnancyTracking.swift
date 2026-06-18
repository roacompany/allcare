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

    // MARK: - ContractionSession (5-1-1)

    func test_511_metWhenIntervalsTightAndSustained() {
        // 5분 간격·1분 지속·1시간 지속 → 충족
        let now = Date()
        var session = ContractionSession(pregnancyId: "p1")
        for i in 0..<13 {
            let start = now.addingTimeInterval(Double(i) * 300)        // 5분 간격
            session.contractions.append(ContractionEvent(startedAt: start, endedAt: start.addingTimeInterval(60)))
        }
        XCTAssertTrue(session.meets511(asOf: now.addingTimeInterval(13 * 300)))
    }

    func test_511_notMetWhenSparse() {
        // 15분 간격 → 미충족
        let now = Date()
        var session = ContractionSession(pregnancyId: "p1")
        for i in 0..<5 {
            let start = now.addingTimeInterval(Double(i) * 900)
            session.contractions.append(ContractionEvent(startedAt: start, endedAt: start.addingTimeInterval(30)))
        }
        XCTAssertFalse(session.meets511(asOf: now.addingTimeInterval(5 * 900)))
    }

    func test_511_notMetWhenShortHistory() {
        // 5분 간격·1분 지속이지만 20분만 → 1시간 미충족
        let now = Date()
        var session = ContractionSession(pregnancyId: "p1")
        for i in 0..<5 {
            let start = now.addingTimeInterval(Double(i) * 300)
            session.contractions.append(ContractionEvent(startedAt: start, endedAt: start.addingTimeInterval(60)))
        }
        XCTAssertFalse(session.meets511(asOf: now.addingTimeInterval(5 * 300)))
    }

    @MainActor
    func test_saveContractionSession_upsertsById() async {
        let mock = MockPregnancyFirestore()
        let vm = PregnancyViewModel(firestoreService: mock)
        vm.activePregnancy = Pregnancy(lmpDate: nil, dueDate: nil, fetusCount: 1, babyNickname: "t")
        var session = ContractionSession(pregnancyId: "p1")
        await vm.saveContractionSession(session, userId: "u1")
        XCTAssertEqual(vm.contractionSessions.count, 1)
        // 같은 id 재저장 → 교체(중복 추가 아님)
        session.contractions.append(ContractionEvent(startedAt: Date()))
        await vm.saveContractionSession(session, userId: "u1")
        XCTAssertEqual(vm.contractionSessions.count, 1)
        XCTAssertEqual(mock.saveContractionSessionCalls.count, 2)
    }

    // MARK: - M2: 공유 임신 데이터는 owner 경로로 저장

    @MainActor
    func test_addVitalEntry_routesToOwnerPath_forSharedPregnancy() async {
        let mock = MockPregnancyFirestore()
        let vm = PregnancyViewModel(firestoreService: mock)
        var shared = Pregnancy(lmpDate: nil, dueDate: nil, fetusCount: 1, babyNickname: "공유")
        shared.ownerUserId = "owner-uid"
        vm.activePregnancy = shared
        // 파트너(partner-uid)가 입력해도 owner-uid 경로로 저장돼야 함
        await vm.addVitalEntry(PregnancyVitalEntry(pregnancyId: shared.id, glucose: 90), userId: "partner-uid")
        XCTAssertEqual(mock.saveVitalEntryUserIds.last, "owner-uid")
    }

    /// 파트너가 토글해도 체크리스트 저장은 owner 경로로 가야 한다 (#41 격리).
    @MainActor
    func test_toggleChecklistItem_routesToOwnerPath_forSharedPregnancy() async {
        let mock = MockPregnancyFirestore()
        let vm = PregnancyViewModel(firestoreService: mock)
        var shared = Pregnancy(lmpDate: nil, dueDate: nil, fetusCount: 1, babyNickname: "공유")
        shared.ownerUserId = "owner-uid"
        vm.activePregnancy = shared
        let item = PregnancyChecklistItem(pregnancyId: shared.id, title: "엽산", category: "trimester1")
        await vm.toggleChecklistItem(item, userId: "partner-uid")
        XCTAssertEqual(mock.saveChecklistItemUserIds.last, "owner-uid")
    }

    /// 파트너가 항목을 추가해도 owner 경로로 저장돼야 한다 (#41 격리).
    @MainActor
    func test_addChecklistItem_routesToOwnerPath_forSharedPregnancy() async {
        let mock = MockPregnancyFirestore()
        let vm = PregnancyViewModel(firestoreService: mock)
        var shared = Pregnancy(lmpDate: nil, dueDate: nil, fetusCount: 1, babyNickname: "공유")
        shared.ownerUserId = "owner-uid"
        vm.activePregnancy = shared
        await vm.addChecklistItem(title: "병원 예약", userId: "partner-uid")
        XCTAssertEqual(mock.saveChecklistItemUserIds.last, "owner-uid")
    }

    /// 파트너가 검진을 저장/토글해도 owner 경로로 가야 한다 (#41 격리).
    @MainActor
    func test_savePrenatalVisit_routesToOwnerPath_forSharedPregnancy() async {
        let mock = MockPregnancyFirestore()
        let vm = PregnancyViewModel(firestoreService: mock)
        var shared = Pregnancy(lmpDate: nil, dueDate: nil, fetusCount: 1, babyNickname: "공유")
        shared.ownerUserId = "owner-uid"
        vm.activePregnancy = shared
        let visit = PrenatalVisit(pregnancyId: shared.id, scheduledAt: Date())
        await vm.savePrenatalVisit(visit, userId: "partner-uid")
        XCTAssertEqual(mock.savePrenatalVisitUserIds.last, "owner-uid")
    }

    /// 파트너가 체중을 기록해도 owner 경로로 저장돼야 한다 (#41 격리).
    @MainActor
    func test_addWeightEntry_routesToOwnerPath_forSharedPregnancy() async {
        let mock = MockPregnancyFirestore()
        let vm = PregnancyViewModel(firestoreService: mock)
        var shared = Pregnancy(lmpDate: nil, dueDate: nil, fetusCount: 1, babyNickname: "공유")
        shared.ownerUserId = "owner-uid"
        vm.activePregnancy = shared
        let entry = PregnancyWeightEntry(pregnancyId: shared.id, weight: 60, unit: "kg", measuredAt: Date())
        await vm.addWeightEntry(entry, userId: "partner-uid")
        XCTAssertEqual(mock.saveWeightEntryUserIds.last, "owner-uid")
    }

    /// 파트너가 증상을 기록해도 owner 경로로 저장돼야 한다 (#41 격리).
    @MainActor
    func test_addSymptom_routesToOwnerPath_forSharedPregnancy() async {
        let mock = MockPregnancyFirestore()
        let vm = PregnancyViewModel(firestoreService: mock)
        var shared = Pregnancy(lmpDate: nil, dueDate: nil, fetusCount: 1, babyNickname: "공유")
        shared.ownerUserId = "owner-uid"
        vm.activePregnancy = shared
        let symptom = PregnancySymptom(pregnancyId: shared.id, memo: "메모", occurredAt: Date())
        await vm.addSymptom(symptom, userId: "partner-uid")
        XCTAssertEqual(mock.saveSymptomUserIds.last, "owner-uid")
    }

    // MARK: - 정서기록 (PregnancyMood) — 가벼운 기분 체크인

    func test_pregnancyMood_codableRoundtrip() throws {
        let m = PregnancyMood(pregnancyId: "p1", mood: .good, memo: "산책함", occurredAt: Date())
        let data = try JSONEncoder().encode(m)
        let decoded = try JSONDecoder().decode(PregnancyMood.self, from: data)
        XCTAssertEqual(decoded.mood, .good)
        XCTAssertEqual(decoded.memo, "산책함")
    }

    func test_mood_allCasesHaveDisplayAndEmoji() {
        for mood in PregnancyMood.Mood.allCases {
            XCTAssertFalse(mood.displayName.isEmpty)
            XCTAssertFalse(mood.emoji.isEmpty)
        }
    }

    func test_mood_rawValuesStableForPersistence() {
        // rawValue = Firestore 영구 저장값. 변경 금지.
        XCTAssertEqual(PregnancyMood.Mood.great.rawValue, "great")
        XCTAssertEqual(PregnancyMood.Mood.hard.rawValue, "hard")
        XCTAssertEqual(PregnancyMood.Mood.allCases.count, 5)
    }

    @MainActor
    func test_addMood_routesToOwnerPath_forSharedPregnancy() async {
        let mock = MockPregnancyFirestore()
        let vm = PregnancyViewModel(firestoreService: mock)
        var shared = Pregnancy(lmpDate: nil, dueDate: nil, fetusCount: 1, babyNickname: "공유")
        shared.ownerUserId = "owner-uid"
        vm.activePregnancy = shared
        // 파트너가 기록해도 owner 경로로 저장돼야 함(#41)
        await vm.addMood(PregnancyMood(pregnancyId: shared.id, mood: .good), userId: "partner-uid")
        XCTAssertEqual(mock.saveMoodUserIds.last, "owner-uid")
        XCTAssertEqual(vm.moods.first?.mood, .good)
    }
}

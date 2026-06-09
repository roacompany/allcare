import XCTest
@testable import BabyCare

/// 저장된 기록 편집 영속 회귀 방지 (2026-06-10 버그: 캘린더에서 다른 날짜 기록의 종료시간 변경이 저장 안 됨).
@MainActor
final class ActivityEditPersistenceTests: XCTestCase {

    // MARK: - 버그 재현: todayActivities 에 없는 기록도 저장되어야 함

    func testUpdateActivity_recordNotInTodayActivities_persistsToFirestore() async {
        let mock = MockActivityFirestore()
        let vm = ActivityViewModel(firestoreService: mock)
        // todayActivities 비어 있음 → 캘린더에서 과거 날짜의 수면 기록 종료시간을 편집하는 상황
        var pastSleep = Activity(babyId: "b", type: .sleep, startTime: Date().addingTimeInterval(-86_400))
        pastSleep.endTime = Date().addingTimeInterval(-80_000)
        pastSleep.duration = 6_400

        await vm.updateActivity(pastSleep, userId: "u")

        XCTAssertEqual(mock.saveActivityCalls.map(\.id), [pastSleep.id],
                       "todayActivities에 없는 과거 기록도 Firestore에 저장되어야 한다 (캘린더 종료시간 편집)")
        XCTAssertEqual(mock.saveActivityCalls.first?.endTime, pastSleep.endTime,
                       "변경된 종료시간이 저장 payload에 포함되어야 한다")
    }

    // MARK: - 오늘 기록 경로(대시보드) 회귀 방지

    func testUpdateActivity_recordInTodayActivities_savesAndOptimisticallyReplaces() async {
        let mock = MockActivityFirestore()
        let vm = ActivityViewModel(firestoreService: mock)
        var record = Activity(babyId: "b", type: .feedingBottle, amount: 100)
        vm.todayActivities = [record]
        record.amount = 150

        await vm.updateActivity(record, userId: "u")

        XCTAssertEqual(mock.saveActivityCalls.count, 1, "오늘 기록도 Firestore에 저장")
        XCTAssertEqual(vm.todayActivities.first?.amount, 150, "todayActivities 낙관적 교체 유지")
    }

    // MARK: - .unknown 센티넬은 편집/영속 불가 유지

    func testUpdateActivity_unknownSentinel_neverPersists() async {
        let mock = MockActivityFirestore()
        let vm = ActivityViewModel(firestoreService: mock)
        let unknown = Activity(babyId: "b", type: .unknown)

        await vm.updateActivity(unknown, userId: "u")

        XCTAssertTrue(mock.saveActivityCalls.isEmpty, ".unknown 센티넬은 영속 차단 유지")
    }
}

import XCTest
@testable import BabyCare

/// `KoreanPrenatalSchedule` 주차 자동매핑 순수 로직 테스트 (③검진 Phase A).
final class PrenatalScheduleTests: XCTestCase {

    private func item(_ id: String) -> KoreanPrenatalScheduleItem {
        KoreanPrenatalSchedule.standardItems.first { $0.id == id }!
    }

    func test_standardItems_nonEmpty_validRanges() {
        let items = KoreanPrenatalSchedule.standardItems
        XCTAssertFalse(items.isEmpty)
        for it in items {
            XCTAssertLessThanOrEqual(it.weekStart, it.weekEnd, "\(it.id) week range invalid")
        }
    }

    func test_status_pastCurrentFuture() {
        let nt = item("nt-first") // 11~13
        XCTAssertEqual(KoreanPrenatalSchedule.status(for: nt, currentWeek: 12), .current)
        XCTAssertEqual(KoreanPrenatalSchedule.status(for: nt, currentWeek: 14), .past)
        XCTAssertEqual(KoreanPrenatalSchedule.status(for: nt, currentWeek: 9), .future)
    }

    func test_status_boundaryInclusive() {
        let nt = item("nt-first") // 11~13 inclusive both ends
        XCTAssertEqual(KoreanPrenatalSchedule.status(for: nt, currentWeek: 11), .current)
        XCTAssertEqual(KoreanPrenatalSchedule.status(for: nt, currentWeek: 13), .current)
    }

    func test_status_nilWeek_isFuture() {
        XCTAssertEqual(KoreanPrenatalSchedule.status(for: item("nt-first"), currentWeek: nil), .future)
    }

    func test_timeline_sortedAndStatusMapped() {
        let t = KoreanPrenatalSchedule.timeline(currentWeek: 26)
        XCTAssertEqual(t.count, KoreanPrenatalSchedule.standardItems.count)
        XCTAssertEqual(t.map { $0.item.weekStart }, t.map { $0.item.weekStart }.sorted())
        XCTAssertEqual(t.first { $0.id == "gdm-screening" }?.status, .current)    // 24~28
        XCTAssertEqual(t.first { $0.id == "detailed-ultrasound" }?.status, .past)  // 18~24
        XCTAssertEqual(t.first { $0.id == "gbs-screening" }?.status, .future)     // 35~37
    }

    func test_currentItem() {
        XCTAssertEqual(KoreanPrenatalSchedule.currentItem(currentWeek: 26)?.id, "gdm-screening")
        XCTAssertNil(KoreanPrenatalSchedule.currentItem(currentWeek: 100))
        XCTAssertNil(KoreanPrenatalSchedule.currentItem(currentWeek: nil))
    }
}

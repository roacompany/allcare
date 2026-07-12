import XCTest
@testable import BabyCare

/// 유축 재고 순수 로직 (P3) — 유통기한·FIFO·만료·음수. 자체 클래스(도메인 분리).
final class PumpedMilkInventoryTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    private func pump(_ id: String, _ amount: Double, agoHours: Double, _ storage: PumpStorage) -> PumpedMilkInventory.PumpInput {
        PumpedMilkInventory.PumpInput(
            id: id, amount: amount,
            pumpedAt: now.addingTimeInterval(-agoHours * 3600),
            storage: storage
        )
    }

    func test_expiry_byStorage() {
        let t = Date(timeIntervalSince1970: 0)
        XCTAssertEqual(PumpedMilkInventory.expiry(pumpedAt: t, storage: .room), t.addingTimeInterval(4 * 3600))
        XCTAssertEqual(PumpedMilkInventory.expiry(pumpedAt: t, storage: .fridge), t.addingTimeInterval(4 * 24 * 3600))
    }

    func test_compute_fifo_deductsOldestFirst() {
        // 냉장 2배치: 오래된 100(2h 전), 새 150(1h 전). 소비 120 → 오래된 소진 + 새 것 20 차감.
        let pumps = [pump("old", 100, agoHours: 2, .fridge), pump("new", 150, agoHours: 1, .fridge)]
        let s = PumpedMilkInventory.compute(pumps: pumps, totalConsumed: 120, now: now)
        XCTAssertEqual(s.totalRemaining, 130)   // (100-100)+(150-20)
        XCTAssertEqual(s.batches.first { $0.id == "old" }?.remaining, 0)
        XCTAssertEqual(s.batches.first { $0.id == "new" }?.remaining, 130)
    }

    func test_compute_expired_excludedAndNotConsumed() {
        // 실온 5h 전(shelfLife 4h)=만료 80, 냉장 1h 전 신선 100. 소비 50 → 신선서만 차감.
        let pumps = [pump("expired", 80, agoHours: 5, .room), pump("fresh", 100, agoHours: 1, .fridge)]
        let s = PumpedMilkInventory.compute(pumps: pumps, totalConsumed: 50, now: now)
        XCTAssertEqual(s.totalRemaining, 50)   // 만료 제외, 신선 100-50
        XCTAssertTrue(s.batches.first { $0.id == "expired" }?.isExpired == true)
        XCTAssertEqual(s.batches.first { $0.id == "expired" }?.remaining, 80)  // 만료분은 소비 안 됨
    }

    func test_compute_negative_clampedToZero() {
        let pumps = [pump("a", 50, agoHours: 1, .fridge)]
        let s = PumpedMilkInventory.compute(pumps: pumps, totalConsumed: 200, now: now)
        XCTAssertEqual(s.totalRemaining, 0)
    }

    func test_compute_soonestExpiry_nearest() {
        let pumps = [pump("fridge", 50, agoHours: 1, .fridge), pump("room", 50, agoHours: 1, .room)]
        let s = PumpedMilkInventory.compute(pumps: pumps, totalConsumed: 0, now: now)
        let roomExp = PumpedMilkInventory.expiry(pumpedAt: now.addingTimeInterval(-3600), storage: .room)
        XCTAssertEqual(s.soonestExpiry, roomExp)   // 실온(4h)이 냉장(4일)보다 임박
    }

    func test_compute_empty() {
        let s = PumpedMilkInventory.compute(pumps: [], totalConsumed: 0, now: now)
        XCTAssertEqual(s.totalRemaining, 0)
        XCTAssertNil(s.soonestExpiry)
    }
}

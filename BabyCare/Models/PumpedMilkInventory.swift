import Foundation

/// 유축 모유 보관 방식 — 유통기한 산정 기준. rawValue = Firestore 영구 계약(신규).
enum PumpStorage: String, Codable, CaseIterable, Hashable {
    case room = "room"        // 실온
    case fridge = "fridge"    // 냉장
    case freezer = "freezer"  // 냉동

    var displayName: String {
        switch self {
        case .room: "실온"
        case .fridge: "냉장"
        case .freezer: "냉동"
        }
    }

    /// ⚠️ 의학 초안 (산부인과/소아과 감수 전) — CDC/모유수유 보관 가이드 근거.
    /// 확정 전 UI는 반드시 면책 문구 동반(safety.md). 감수 후 이 상수만 교체.
    var shelfLife: TimeInterval {
        switch self {
        case .room: 4 * 3600                 // 4시간
        case .fridge: 4 * 24 * 3600          // 4일
        case .freezer: 6 * 30 * 24 * 3600    // 약 6개월
        }
    }
}

/// 유축 재고 순수 계산 — 짜기(생산) − 유축 먹이기(소비), FIFO 차감 + 유통기한. 부수효과 없음(TDD).
enum PumpedMilkInventory {

    /// 짜기 1건 = 저장 배치 입력.
    struct PumpInput: Equatable {
        let id: String
        let amount: Double
        let pumpedAt: Date
        let storage: PumpStorage
    }

    /// 계산된 배치 상태.
    struct Batch: Equatable, Identifiable {
        let id: String
        let amount: Double
        let pumpedAt: Date
        let storage: PumpStorage
        let expiresAt: Date
        var remaining: Double      // FIFO 차감 후 남은 양
        var isExpired: Bool
    }

    struct State: Equatable {
        var totalRemaining: Double       // 만료 제외 잔량
        var batches: [Batch]             // 유통기한 임박(오래된) 순
        var soonestExpiry: Date?         // 미만료 배치 중 가장 임박
    }

    /// 유통기한 = 짜낸 시각 + 보관별 shelfLife.
    static func expiry(pumpedAt: Date, storage: PumpStorage) -> Date {
        pumpedAt.addingTimeInterval(storage.shelfLife)
    }

    /// - pumps: 짜기 배치 입력 (feedingPumping + storage)
    /// - totalConsumed: 유축 먹이기 총량 (feedingBottle+breastMilk amount 합)
    /// - now: 기준 시각
    /// FIFO: 소비 총량을 **가장 오래된 배치부터** 차감(버림 최소화). 만료 배치는 totalRemaining 제외(표시는 유지).
    /// 음수 방지: 소비 > 생산이면 잔량 0.
    static func compute(pumps: [PumpInput], totalConsumed: Double, now: Date) -> State {
        // 오래된 순 정렬 (FIFO)
        let sorted = pumps.sorted { $0.pumpedAt < $1.pumpedAt }
        var consumed = max(0, totalConsumed)

        var batches: [Batch] = sorted.map { p in
            let exp = expiry(pumpedAt: p.pumpedAt, storage: p.storage)
            let expired = exp < now
            var remaining = p.amount
            // 만료 배치는 소비 대상 아님(안 먹임) — 미만료 오래된 것부터만 차감
            if !expired {
                let take = min(consumed, p.amount)
                consumed -= take
                remaining = p.amount - take
            }
            return Batch(
                id: p.id,
                amount: p.amount,
                pumpedAt: p.pumpedAt,
                storage: p.storage,
                expiresAt: exp,
                remaining: remaining,
                isExpired: expired
            )
        }

        // 잔량 있는 배치만, 유통기한 임박(=expiresAt 이른) 순 정렬 → 화면/FIFO 표시
        batches.sort { $0.expiresAt < $1.expiresAt }

        let total = batches
            .filter { !$0.isExpired }
            .reduce(0) { $0 + $1.remaining }

        let soonest = batches
            .filter { !$0.isExpired && $0.remaining > 0 }
            .map(\.expiresAt)
            .min()

        return State(totalRemaining: total, batches: batches, soonestExpiry: soonest)
    }
}

extension PumpedMilkInventory {
    /// Activity 목록 → 재고 State. feedingPumping(+storage)=배치, feedingBottle+breastMilk=소비.
    /// storage nil(구 기록)=냉장 가정(spec §2.4). pumpDiscarded=true 배치 제외.
    static func fromActivities(_ activities: [Activity], now: Date) -> State {
        let pumps = activities
            .filter { $0.type == .feedingPumping && $0.pumpDiscarded != true }
            .map { PumpInput(id: $0.id, amount: $0.amount ?? 0, pumpedAt: $0.startTime, storage: $0.pumpStorage ?? .fridge) }
        let consumed = activities
            .filter { $0.isBreastMilkBottle }
            .reduce(0.0) { $0 + ($1.amount ?? 0) }
        return compute(pumps: pumps, totalConsumed: consumed, now: now)
    }
}

extension PumpedMilkInventory.Batch {
    /// 배치 신선도 — 재고 화면 상태 뱃지 (신선 / 임박=24h 내 / 만료).
    enum Freshness: Equatable { case fresh, soon, expired }

    func freshness(now: Date) -> Freshness {
        let remaining = expiresAt.timeIntervalSince(now)
        if remaining <= 0 { return .expired }
        if remaining < AppConstants.secondsPerDay { return .soon }
        return .fresh
    }
}

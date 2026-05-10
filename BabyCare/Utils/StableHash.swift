import Foundation

/// DJB2 결정론적 해시 — 코호트 기반 점진 롤아웃(rollout %)에 사용.
/// Swift.hashValue / Int.random 사용 금지 (비결정론적).
enum StableHash {
    /// DJB2 알고리즘: 동일 입력 → 항상 동일 출력 (deterministic).
    static func djb2(_ s: String) -> UInt64 {
        var hash: UInt64 = 5381
        for c in s.utf8 {
            hash = ((hash &<< 5) &+ hash) &+ UInt64(c)
        }
        return hash
    }

    /// userId를 0..<outOf 범위의 버킷으로 매핑.
    /// 예: bucket(uid, outOf: 100) < 10 → 10% 롤아웃 대상
    static func bucket(_ uid: String, outOf: UInt64 = 100) -> UInt64 {
        djb2(uid) % outOf
    }
}

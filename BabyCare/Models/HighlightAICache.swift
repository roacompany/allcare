import Foundation

/// AI 주간 하이라이트 캐시. Firestore 영속, TTL 7일.
///
/// Firestore 경로: `users/{uid}/babies/{bid}/highlightCache/{weekKey}_{metricKey}`
/// `weekKey` = ISO 주차 (예: "2026W19"), `metricKey` = 카테고리 기반 키 (예: "feeding_total_oz").
struct HighlightAICache: Identifiable, Codable, Hashable {
    /// Firestore 문서 ID. `{weekKey}_{metricKey}` 조합.
    var id: String { "\(weekKey)_\(metricKey)" }

    /// ISO 주차 키. 예: "2026W19".
    let weekKey: String

    /// 카테고리 기반 metric 키. 예: "feeding_total_oz".
    /// allowlist: feeding / sleep / diaper / health 접두사만 허용 (Firestore rules와 동일).
    let metricKey: String

    /// AI 생성 요약 텍스트. ≤200자 제한 (서버 사이드에서 강제).
    let summary: String

    /// 캐시 생성 시각.
    let createdAt: Date

    /// RC 가중치 핑거프린트. nil이면 RC 정보 미포함 빌드.
    /// RC weight 변경 시 hash 불일치 → 캐시 무효화 신호.
    let rcVersionHash: UInt32?

    /// TTL 만료 여부. 생성 후 7일 초과 시 true.
    var isExpired: Bool {
        Date().timeIntervalSince(createdAt) > AppConstants.highlightCacheTTLSeconds
    }
}

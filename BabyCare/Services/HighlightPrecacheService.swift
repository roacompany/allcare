import Foundation

// MARK: - HighlightPrecacheService
//
// 주간 하이라이트 AI 요약 사전 캐시 워커.
//
// 호출 위치:
//   1. 앱 launch: BabyCareApp .task modifier (1회)
//   2. Pull-to-refresh: DashboardView .refreshable 액션
//
// Codex R-2: scenePhase=.active hook 절대 사용 금지 (비용 폭주 방지).
//
// 멱등성 보장:
//   - UserDefaults 로컬 키 "highlight.precache.{weekKey}" 존재 시 skip (TTL-based)
//   - in-flight 가드: isPrecomputing=true 시 중복 호출 즉시 return
//
// RC 가드:
//   - FeatureFlagService.isHighlightV2Enabled(userId:) == false 시 skip
//
// Pregnancy defense-in-depth:
//   - metricKey.hasPrefix("pregnancy_") 시 reject (InsightService.topHighlights에서
//     이미 필터링되었어도 추가 안전망)

@MainActor @Observable
final class HighlightPrecacheService {

    // MARK: - State

    /// in-flight 가드: 동시 호출 방지.
    private var isPrecomputing: Bool = false

    // MARK: - Dependencies

    private let insightService: InsightService
    private let aiSummaryService: HighlightAISummaryServiceProviding
    private let flagService: FeatureFlagService

    // MARK: - UserDefaults TTL 키

    /// 멱등성 키 prefix. 실제 키: "highlight.precache.{weekKey}".
    nonisolated static let precacheKeyPrefix = "highlight.precache."

    /// 로컬 idempotent 키 (weekKey 단위).
    private func idempotentKey(for weekKey: String) -> String {
        "\(HighlightPrecacheService.precacheKeyPrefix)\(weekKey)"
    }

    // MARK: - Init

    /// DI 생성자 (싱글톤 및 테스트 사용).
    init(
        insightService: InsightService,
        aiSummaryService: HighlightAISummaryServiceProviding,
        flagService: FeatureFlagService
    ) {
        self.insightService = insightService
        self.aiSummaryService = aiSummaryService
        self.flagService = flagService
    }

    // MARK: - Public API

    /// 이번 주 상위 N=3 InsightCandidate에 대해 AI 요약을 사전 캐시합니다.
    ///
    /// - 멱등성: UserDefaults 키 "highlight.precache.{weekKey}" 존재 시 skip
    /// - in-flight 가드: 동시 호출 시 1회만 실행
    /// - RC 가드: isHighlightV2Enabled==false 시 skip
    /// - Pregnancy defense-in-depth: pregnancy_ metricKey는 즉시 reject
    ///
    /// - Parameters:
    ///   - userId: Firebase Auth currentUserId (babyVM.dataUserId() 결과)
    ///   - babyId: 대상 아기 ID
    ///   - weekKey: ISO 주차 키 (예: "2026W19")
    func precomputeIfNeeded(
        userId: String,
        babyId: String,
        weekKey: String
    ) async {
        // ── in-flight 가드 ────────────────────────────────────────────────────
        guard !isPrecomputing else { return }

        // ── RC 가드 ───────────────────────────────────────────────────────────
        let enabled = await flagService.isHighlightV2Enabled(userId: userId)
        guard enabled else { return }

        // ── 멱등성 체크 (UserDefaults TTL 키) ────────────────────────────────
        let key = idempotentKey(for: weekKey)
        if UserDefaults.standard.bool(forKey: key) { return }

        // ── in-flight 플래그 설정 ─────────────────────────────────────────────
        isPrecomputing = true
        defer { isPrecomputing = false }

        // ── AppContext: babyOnly 고정 ─────────────────────────────────────────
        // precomputeIfNeeded는 babyId 존재를 전제로 호출됨 (pregnancyOnly user는
        // valid babyId 없음 → 호출 불가). babyOnly / both 모두 baby UI 기반이므로
        // topHighlights(for: .babyOnly) 호출은 안전.
        // InsightService.topHighlights가 pregnancy_ metricKey를 이미 필터링하지만
        // defense-in-depth로 precache 레이어에서도 추가 guard.
        let candidates = insightService.topHighlights(
            for: .babyOnly,
            weights: InsightWeights.fromRC()
        )

        guard !candidates.isEmpty else { return }

        // ── Top N=3 각각 AI 요약 사전 캐시 ────────────────────────────────────
        let topN = Array(candidates.prefix(3))
        for candidate in topN {
            // ── Pregnancy defense-in-depth reject ────────────────────────────
            guard !candidate.metricKey.hasPrefix("pregnancy_") else {
                assertionFailure(
                    "HighlightPrecacheService: pregnancy_ metricKey는 precache 대상이 될 수 없습니다. metricKey=\(candidate.metricKey)"
                )
                continue
            }

            let sparkline = insightService.sparklineData(for: candidate.metricKey)
            // HighlightAISummaryService.summarize 내부에서 stale-while-revalidate 캐시 처리
            _ = try? await aiSummaryService.summarize(
                candidate: candidate,
                weekKey: weekKey,
                babyId: babyId,
                userId: userId,
                sparkline: sparkline
            )
        }

        // ── 멱등성 키 저장 (이번 주 재호출 skip) ─────────────────────────────
        UserDefaults.standard.set(true, forKey: key)
    }
}

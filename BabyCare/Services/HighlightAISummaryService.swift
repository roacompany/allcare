import Foundation

// MARK: - Protocol

/// HighlightAISummaryService 의존성 주입 인터페이스 (mock 테스트 가능).
///
/// **아키텍처**: iOS는 Firestore `highlightCache` 컬렉션을 read-only로 조회만 한다.
/// AI 요약 생성은 babycare-admin 측 Vercel Cron + Mac LaunchAgent worker가
/// 사용자 본인 Claude Code Pro 구독으로 처리한 후 Firestore에 write한다.
/// iOS 앱은 Anthropic API 키를 보유하거나 직접 LLM을 호출하지 않는다.
protocol HighlightAISummaryServiceProviding: Sendable {
    /// 캐시된 AI 요약 조회. 캐시 미존재 또는 만료 시 nil 반환.
    ///
    /// - Parameters:
    ///   - candidate: 상위 InsightCandidate (metricKey 검증용)
    ///   - weekKey: ISO 주차 키 (예: "2026W19")
    ///   - babyId: 대상 아기 ID (캐시 경로)
    ///   - userId: 데이터 소유자 uid (`babyVM.dataUserId()` 결과)
    /// - Returns: 200자 이내 AI 요약 텍스트 (가드레일 통과 후), 캐시 미존재/만료 시 nil
    /// - Throws: `HighlightAISummaryError.pregnancyMetricRejected` (defense in depth)
    func fetchCachedSummary(
        candidate: InsightCandidate,
        weekKey: String,
        babyId: String,
        userId: String
    ) async throws -> String?
}

// MARK: - Errors

enum HighlightAISummaryError: LocalizedError {
    case pregnancyMetricRejected(String)

    var errorDescription: String? {
        switch self {
        case .pregnancyMetricRejected(let key):
            return "pregnancy_ metricKey는 AI 요약에 사용할 수 없습니다: \(key)"
        }
    }
}

// MARK: - Implementation

/// Firestore `highlightCache` 컬렉션 read-only 조회 서비스.
///
/// **AI 생성 책임은 iOS 측에 없음** — babycare-admin Vercel Cron + Mac worker가
/// 본인 Claude Code Pro 구독으로 배치 처리하여 Firestore에 미리 저장한다.
///
/// 가드:
/// - pregnancy_ metricKey 입력 즉시 reject (정상 흐름에서는 InsightService 단계에서
///   이미 필터링되지만 defense in depth)
/// - 200자 클램프는 admin 측에서 1차, 클라이언트에서 2차 (이미 HighlightDetailSheet에서 처리)
/// - 면책 문구는 admin 측 AIGuardrail에서 보장
///
/// 만료 정책: `HighlightAICache.isExpired` (168h TTL). 만료 시 nil 반환 → 호출부는
/// `candidate.detail` fallback 사용. admin batch가 다음 사이클에서 갱신.
final class HighlightAISummaryService: HighlightAISummaryServiceProviding {

    // MARK: - Dependencies

    private let firestoreProvider: HighlightFirestoreProviding

    // MARK: - Init

    init(firestoreProvider: HighlightFirestoreProviding = FirestoreService.shared) {
        self.firestoreProvider = firestoreProvider
    }

    // MARK: - Public API

    func fetchCachedSummary(
        candidate: InsightCandidate,
        weekKey: String,
        babyId: String,
        userId: String
    ) async throws -> String? {
        let metricKey = candidate.metricKey

        // ── pregnancy_ metricKey reject (defense in depth) ────────────────
        // throw가 계약. assertionFailure 사용 금지 — DEBUG에서 SIGTRAP으로
        // throw 도달 전 abort 되며 단위 테스트가 catch 불가 (테스트가 검증하는 것은 throw).
        if metricKey.hasPrefix("pregnancy_") {
            throw HighlightAISummaryError.pregnancyMetricRejected(metricKey)
        }

        // ── Firestore read만 (admin batch가 미리 채워둔 캐시) ────────────
        let cached = await firestoreProvider.fetchHighlightAICache(
            userId: userId,
            babyId: babyId,
            weekKey: weekKey,
            metricKey: metricKey
        )

        guard let hit = cached, !hit.isExpired else {
            return nil
        }
        // 캐시 적중률 telemetry — metricKey만 (weekKey/babyId 금지)
        AnalyticsService.shared.trackEvent(
            AnalyticsEvents.highlightCacheHit,
            parameters: [AnalyticsParams.metricKey: metricKey]
        )
        return hit.summary
    }
}

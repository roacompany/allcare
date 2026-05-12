import FirebaseFunctions
import Foundation

// MARK: - Protocol

/// HighlightAISummaryService 의존성 주입 인터페이스 (mock 테스트 가능).
protocol HighlightAISummaryServiceProviding: Sendable {
    /// AI 요약 생성.
    ///
    /// - Parameters:
    ///   - candidate: 상위 InsightCandidate (metricKey, changePercent, currentValue, sampleSize)
    ///   - weekKey: ISO 주차 키 (예: "2026W19")
    ///   - babyId: 대상 아기 ID (캐시 저장 경로)
    ///   - userId: 데이터 소유자 uid (babyVM.dataUserId() 결과)
    ///   - sparkline: 최근 4주 수치 (최신→과거)
    /// - Returns: 200자 이내 AI 요약 텍스트 (가드레일 통과 후 면책 문구 포함)
    /// - Throws: `HighlightAISummaryError`
    func summarize(
        candidate: InsightCandidate,
        weekKey: String,
        babyId: String,
        userId: String,
        sparkline: [Double]
    ) async throws -> String
}

// MARK: - Errors

enum HighlightAISummaryError: LocalizedError {
    case pregnancyMetricRejected(String)
    case functionsCallFailed(Error)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .pregnancyMetricRejected(let key):
            return "pregnancy_ metricKey는 AI 요약에 사용할 수 없습니다: \(key)"
        case .functionsCallFailed(let err):
            return "AI 요약 요청에 실패했습니다: \(err.localizedDescription)"
        case .invalidResponse:
            return "AI 요약 응답을 처리할 수 없습니다."
        }
    }
}

// MARK: - Implementation

/// Firebase Functions `summarizeHighlight` 호출 서비스.
///
/// 보안 원칙:
/// - Anthropic API 키 iOS 번들 금지 — Functions 프록시만 사용
/// - payload에 baby.name / birthDate / 일기 본문 / 임신 데이터 0
/// - 임신 metricKey 입력 즉시 reject (assertionFailure debug + throw)
///
/// 캐시 전략 (Stale-while-revalidate):
/// 1. HighlightAICache fetch
/// 2. 신선하면 즉시 반환 + 백그라운드 갱신
/// 3. 만료/없으면 Functions 호출 + 결과 저장
final class HighlightAISummaryService: HighlightAISummaryServiceProviding {

    // MARK: - Dependencies

    private let firestoreProvider: HighlightFirestoreProviding

    // MARK: - Init

    init(firestoreProvider: HighlightFirestoreProviding = FirestoreService.shared) {
        self.firestoreProvider = firestoreProvider
    }

    // MARK: - Public API

    func summarize(
        candidate: InsightCandidate,
        weekKey: String,
        babyId: String,
        userId: String,
        sparkline: [Double]
    ) async throws -> String {
        let metricKey = candidate.metricKey

        // ── pregnancy_ metricKey reject ────────────────────────────────────
        if metricKey.hasPrefix("pregnancy_") {
            assertionFailure(
                "HighlightAISummaryService: pregnancy_ metricKey는 허용되지 않습니다. metricKey=\(metricKey)"
            )
            throw HighlightAISummaryError.pregnancyMetricRejected(metricKey)
        }

        // ── 1. Cache fetch ─────────────────────────────────────────────────
        let cached = await firestoreProvider.fetchHighlightAICache(
            userId: userId,
            babyId: babyId,
            weekKey: weekKey,
            metricKey: metricKey
        )

        if let hit = cached, !hit.isExpired {
            // 2a. 신선한 캐시 즉시 반환 + 백그라운드 갱신
            Task.detached(priority: .background) { [weak self] in
                try? await self?.fetchAndCache(
                    candidate: candidate,
                    weekKey: weekKey,
                    babyId: babyId,
                    userId: userId,
                    sparkline: sparkline
                )
            }
            return hit.summary
        }

        // 2b. 만료 또는 캐시 없음 → Functions 호출 + 저장
        return try await fetchAndCache(
            candidate: candidate,
            weekKey: weekKey,
            babyId: babyId,
            userId: userId,
            sparkline: sparkline
        )
    }

    // MARK: - Private

    /// Functions 호출 → 200자 클램프 → 가드레일 → 캐시 저장 → 반환.
    @discardableResult
    private func fetchAndCache(
        candidate: InsightCandidate,
        weekKey: String,
        babyId: String,
        userId: String,
        sparkline: [Double]
    ) async throws -> String {
        // ── Functions call ─────────────────────────────────────────────────
        let rawSummary = try await callSummarizeHighlight(
            candidate: candidate,
            weekKey: weekKey,
            sparkline: sparkline
        )

        // ── 200자 hard clamp (1차) ─────────────────────────────────────────
        let clamped = String(rawSummary.prefix(200))

        // ── AIGuardrailService.filter() (면책 문구 포함) ────────────────────
        let filtered = AIGuardrailService.filter(clamped)

        // ── Cache 저장 ─────────────────────────────────────────────────────
        let cache = HighlightAICache(
            weekKey: weekKey,
            metricKey: candidate.metricKey,
            summary: filtered,
            createdAt: Date(),
            rcVersionHash: nil
        )
        try? await firestoreProvider.saveHighlightAICache(
            cache,
            userId: userId,
            babyId: babyId
        )

        return filtered
    }

    /// Firebase Functions `summarizeHighlight` httpsCallable 호출.
    ///
    /// payload: 집계 수치만 포함 (changePercent, currentValue, sampleSize, sparkline 4 값)
    /// baby.name / birthDate / 일기 본문 / 임신 데이터 0
    private func callSummarizeHighlight(
        candidate: InsightCandidate,
        weekKey: String,
        sparkline: [Double]
    ) async throws -> String {
        let functions = Functions.functions(region: "asia-northeast3")
        let callable = functions.httpsCallable("summarizeHighlight")

        // payload allowlist: 집계 수치만 전송 (PII 없음)
        let payload: [String: Any] = [
            "weekKey": weekKey,
            "metricKey": candidate.metricKey,
            "changePercent": candidate.changePercent,
            "currentValue": candidate.currentValue,
            "sampleSize": candidate.sampleSize,
            "sparkline": Array(sparkline.prefix(4))
        ]

        do {
            let result = try await callable.call(payload)
            guard let dict = result.data as? [String: Any],
                  let summary = dict["summary"] as? String else {
                throw HighlightAISummaryError.invalidResponse
            }
            return summary
        } catch let error as HighlightAISummaryError {
            throw error
        } catch {
            throw HighlightAISummaryError.functionsCallFailed(error)
        }
    }
}

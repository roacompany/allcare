import Foundation
import SwiftUI

// MARK: - Phase 5: 병원 방문 AI 리포트 ViewModel

enum ReportState {
    case idle
    case analyzing
    case generating
    case done(AIReport)
    case failed(String)

    var isLoading: Bool {
        switch self {
        case .analyzing, .generating: true
        default: false
        }
    }
}

@MainActor
@Observable
final class HospitalReportViewModel {
    var state: ReportState = .idle
    var cachedReport: AIReport?

    // MARK: - 리포트 생성 진입점

    func generate(
        baby: Baby,
        visit: HospitalVisit,
        previousVisitDate: Date?,
        userId: String
    ) async {
        guard !state.isLoading else { return }

        // 캐시 확인
        if let cached = await loadCached(babyId: baby.id, visitId: visit.id, userId: userId) {
            cachedReport = cached
            state = .done(cached)
            return
        }

        state = .analyzing

        // 활동 데이터 로드
        let period = Preprocessor.analysisPeriod(
            scheduledDate: visit.scheduledDate ?? visit.visitDate,
            previousVisitDate: previousVisitDate
        )

        let activities: [Activity]
        do {
            activities = try await FirestoreService.shared.fetchActivities(
                userId: userId,
                babyId: baby.id,
                from: period.from,
                to: period.to
            )
        } catch {
            state = .failed("활동 데이터를 불러오지 못했습니다: \(error.localizedDescription)")
            return
        }

        // 분석 실행
        let result = await AnalysisEngine.shared.run(
            baby: baby,
            visit: visit,
            activities: activities,
            previousVisitDate: previousVisitDate,
            userId: userId
        )

        state = .generating

        // Claude API 리포트 생성
        do {
            let report = try await HospitalReportService.shared.generate(result: result, baby: baby)
            cachedReport = report
            state = .done(report)
        } catch {
            // API 키 없는 경우 알고리즘 결과만으로 리포트 구성
            if let reportError = error as? HospitalReportService.ReportError,
               reportError == .noAPIKey {
                let fallback = buildFallbackReport(result: result, baby: baby)
                cachedReport = fallback
                state = .done(fallback)
            } else {
                state = .failed(error.localizedDescription)
            }
        }
    }

    func reset() {
        state = .idle
        cachedReport = nil
    }

    // MARK: - 캐시 로드

    private func loadCached(babyId: String, visitId: String, userId: String) async -> AIReport? {
        guard let result = await AnalysisEngine.shared.fetchCachedResult(
            babyId: babyId,
            visitId: visitId,
            userId: userId
        ) else { return nil }

        // AnalysisResult에서 AIReport가 저장되지 않으므로 nil 반환 (매번 재생성)
        return nil
    }

    // MARK: - 폴백 리포트 (API 키 없을 때)

    private func buildFallbackReport(result: AnalysisResult, baby: Baby) -> AIReport {
        let patternText = result.patterns.isEmpty ? "특이 패턴 없음" :
            result.patterns.map { describePattern($0) }.joined(separator: ", ")

        let summary = """
        \(baby.name) 아기의 \(result.period.daysCount)일간 기록을 분석했습니다. \
        \(patternText). 아래 체크리스트를 병원 방문 시 활용해주세요.
        """

        let keyChanges = result.prioritizedFlags.prefix(4).map { flag -> String in
            let metric = describeMetric(flag.metric)
            let dir = flag.direction == .up ? "증가" : "감소"
            return "\(metric) \(dir) (σ=\(String(format: "%.1f", flag.sigmaDistance)))"
        }

        let checklist = result.checklistItems.prefix(6).map {
            AIReport.ChecklistItem(question: $0)
        }

        return AIReport(
            summary: summary,
            keyChanges: Array(keyChanges),
            checklistItems: Array(checklist),
            generatedAt: Date()
        )
    }

    private func describePattern(_ pattern: DetectedPattern) -> String {
        switch pattern {
        case .growthSpurt: "성장급등 패턴 감지"
        case .infectionSuspected: "감염 의심 패턴 감지"
        case .dehydrationRisk: "탈수 위험 패턴 감지"
        case .normalVariation: "정상 범위 내 변동"
        }
    }

    private func describeMetric(_ metric: MetricFlag.Metric) -> String {
        switch metric {
        case .feeding: "수유 횟수"
        case .feedingAmount: "수유량"
        case .sleep: "수면 시간"
        case .diaper: "기저귀 횟수"
        case .temperature: "체온"
        }
    }
}

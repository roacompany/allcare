import Foundation

// MARK: - Phase 4: Claude API 연동 — 병원 방문 AI 리포트 생성

final class HospitalReportService: @unchecked Sendable {
    static let shared = HospitalReportService()
    private init() {}

    private static let apiKeyKey = "ai_api_key"
    private var apiKey: String {
        UserDefaults.standard.string(forKey: Self.apiKeyKey) ?? ""
    }

    // MARK: - 리포트 생성

    func generate(result: AnalysisResult, baby: Baby) async throws -> AIReport {
        guard !apiKey.isEmpty else {
            throw ReportError.noAPIKey
        }

        let prompt = buildUserPrompt(result: result, baby: baby)
        let systemPrompt = buildSystemPrompt()

        let raw = try await AIService.ask(
            messages: [AIService.Message(role: "user", content: prompt)],
            systemPrompt: systemPrompt,
            apiKey: apiKey
        )

        let report = parseReport(raw: raw)
        return AIGuardrailService.filterReport(report)
    }

    // MARK: - 시스템 프롬프트

    private func buildSystemPrompt() -> String {
        """
        당신은 경험 많은 소아과 전문의입니다.
        아래 아기의 기록 데이터를 분석하여 부모가 병원 방문 시 활용할 수 있는 리포트를 작성해주세요.

        응답 형식은 반드시 아래 JSON 구조를 따라주세요:
        {
          "summary": "2-3문장의 전체 요약",
          "keyChanges": ["주요 변화 항목 1", "항목 2", "항목 3"],
          "checklistItems": ["의사에게 물어볼 질문 1", "질문 2", "질문 3", "질문 4", "질문 5"]
        }

        주의사항:
        - 한국어로 작성하세요.
        - 의학적 진단은 하지 마세요. 관찰된 패턴만 설명하세요.
        - 부모가 이해하기 쉬운 언어를 사용하세요.
        - keyChanges는 최대 5개, checklistItems는 3~7개로 작성하세요.
        - 반드시 유효한 JSON만 출력하고 다른 텍스트는 포함하지 마세요.

        면책 고지: 이 리포트는 참고용이며 의사의 진단을 대체하지 않습니다.
        """
    }

    // MARK: - 유저 프롬프트 (AnalysisResult JSON 주입)

    private func buildUserPrompt(result: AnalysisResult, baby: Baby) -> String {
        let cal = Calendar.current
        let ageMonths = cal.dateComponents([.month], from: baby.birthDate, to: Date()).month ?? 0
        let periodDays = result.period.daysCount

        // 최근 7일 평균 계산
        let recent = Array(result.dailyAggregates.suffix(7))
        let avgFeeding = recent.isEmpty ? 0 : recent.map { Double($0.feedingCount) }.reduce(0, +) / Double(recent.count)
        let avgSleepHrs = recent.isEmpty ? 0 : recent.map { $0.sleepMinutes / 60.0 }.reduce(0, +) / Double(recent.count)
        let avgDiaper = recent.isEmpty ? 0 : recent.map { Double($0.diaperCount) }.reduce(0, +) / Double(recent.count)

        // 이전 7일 평균
        let baseline = Array(result.dailyAggregates.prefix(7))
        let baseFeeding = baseline.isEmpty ? 0 : baseline.map { Double($0.feedingCount) }.reduce(0, +) / Double(baseline.count)
        let baseSleepHrs = baseline.isEmpty ? 0 : baseline.map { $0.sleepMinutes / 60.0 }.reduce(0, +) / Double(baseline.count)
        let baseDiaper = baseline.isEmpty ? 0 : baseline.map { Double($0.diaperCount) }.reduce(0, +) / Double(baseline.count)

        let patternsStr = result.patterns.map(\.rawValue).joined(separator: ", ")
        let flagsStr = result.prioritizedFlags.prefix(5).map {
            "\($0.metric.rawValue) \($0.direction.rawValue) (σ=\(String(format: "%.1f", $0.sigmaDistance)))"
        }.joined(separator: ", ")
        let checklistStr = result.checklistItems.prefix(5).map { "- \($0)" }.joined(separator: "\n")

        return """
        아기 정보:
        - 이름: \(baby.name)
        - 나이: \(ageMonths)개월 (교정 연령 \(result.correctedAgeInDays)일)
        - 분석 기간: \(periodDays)일

        기간 내 평균 데이터 (최근 7일 vs 기간 초기 7일):
        - 수유 횟수: 최근 \(String(format: "%.1f", avgFeeding))회/일 vs 초기 \(String(format: "%.1f", baseFeeding))회/일
        - 수면 시간: 최근 \(String(format: "%.1f", avgSleepHrs))시간/일 vs 초기 \(String(format: "%.1f", baseSleepHrs))시간/일
        - 기저귀 횟수: 최근 \(String(format: "%.1f", avgDiaper))회/일 vs 초기 \(String(format: "%.1f", baseDiaper))회/일

        감지된 패턴: \(patternsStr.isEmpty ? "없음" : patternsStr)
        주요 이상 지표: \(flagsStr.isEmpty ? "없음" : flagsStr)

        알고리즘이 제안한 체크리스트:
        \(checklistStr.isEmpty ? "- 특이사항 없음" : checklistStr)

        위 데이터를 바탕으로 병원 방문용 AI 리포트를 JSON 형식으로 작성해주세요.
        """
    }

    // MARK: - JSON 파싱

    private func parseReport(raw: String) -> AIReport {
        // JSON 추출 (```json 블록 제거)
        let cleaned = raw
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleaned.data(using: .utf8),
              let json = try? JSONDecoder().decode(RawReportResponse.self, from: data) else {
            // 파싱 실패 시 raw 텍스트를 summary에 넣음
            return AIReport(
                summary: raw,
                keyChanges: [],
                checklistItems: [],
                generatedAt: Date()
            )
        }

        let checklistItems = json.checklistItems.map {
            AIReport.ChecklistItem(question: $0)
        }

        return AIReport(
            summary: json.summary,
            keyChanges: json.keyChanges,
            checklistItems: checklistItems,
            generatedAt: Date()
        )
    }

    private struct RawReportResponse: Decodable {
        let summary: String
        let keyChanges: [String]
        let checklistItems: [String]
    }

    // MARK: - 에러

    enum ReportError: LocalizedError {
        case noAPIKey
        case parseError

        var errorDescription: String? {
            switch self {
            case .noAPIKey:
                return "AI 기능을 사용하려면 설정에서 API 키를 입력해주세요."
            case .parseError:
                return "리포트 생성 중 오류가 발생했습니다."
            }
        }
    }
}

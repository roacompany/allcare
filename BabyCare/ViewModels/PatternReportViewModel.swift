import Foundation

@MainActor @Observable
final class PatternReportViewModel {
    var report: PatternReport?
    var aiInsight: String?
    var selectedPeriod: Period = .week
    var isLoading = false
    var isLoadingAI = false
    var errorMessage: String?

    enum Period: String, CaseIterable {
        case week = "주간"
        case month = "월간"
    }

    private let firestoreService = FirestoreService.shared

    private static let apiKeyKey = "ai_api_key"

    var apiKey: String {
        UserDefaults.standard.string(forKey: Self.apiKeyKey) ?? ""
    }

    var hasAPIKey: Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Load Report

    func loadReport(userId: String, babyId: String) async {
        isLoading = true
        defer { isLoading = false }

        let calendar = Calendar.current
        let endDate = Date()
        let startDate: Date

        switch selectedPeriod {
        case .week:
            startDate = calendar.date(byAdding: .day, value: -7, to: endDate) ?? endDate
        case .month:
            startDate = calendar.date(byAdding: .month, value: -1, to: endDate) ?? endDate
        }

        do {
            let activities = try await firestoreService.fetchActivities(
                userId: userId, babyId: babyId,
                from: startDate.startOfDay, to: endDate.endOfDay
            )

            report = PatternAnalysisService.analyze(
                activities: activities,
                period: selectedPeriod.rawValue,
                startDate: startDate,
                endDate: endDate
            )

            // 기간 변경 시 이전 AI 분석 초기화
            aiInsight = nil
        } catch {
            errorMessage = "데이터를 불러오지 못했습니다."
            report = nil
        }
    }

    // MARK: - AI Insight

    func requestAIInsight(babyName: String, babyAge: String, gender: String) async {
        guard let report else { return }
        guard hasAPIKey else {
            errorMessage = "설정에서 AI API 키를 입력해주세요."
            return
        }

        isLoadingAI = true
        errorMessage = nil
        defer { isLoadingAI = false }

        let prompt = PatternAnalysisService.buildAIPrompt(
            report: report,
            babyName: babyName,
            babyAge: babyAge,
            gender: gender
        )

        let systemPrompt = """
        당신은 경험 많은 소아과 전문의이자 육아 데이터 분석 전문가입니다.
        아기의 행동 패턴 데이터를 분석하여 부모에게 실질적인 인사이트와 조언을 제공합니다.
        - 데이터에서 발견되는 패턴과 특이사항을 명확히 설명하세요.
        - 긍정적인 패턴은 격려하고, 주의할 점은 부드럽게 알려주세요.
        - 구체적이고 실행 가능한 조언을 제공하세요.
        - 한국어로 답변하며, 이모지를 적절히 사용하세요.
        - 답변은 500자 이내로 간결하게 작성하세요.
        """

        do {
            let response = try await AIService.ask(
                messages: [AIService.Message(role: "user", content: prompt)],
                systemPrompt: systemPrompt,
                apiKey: apiKey
            )
            aiInsight = AIGuardrailService.filter(response)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

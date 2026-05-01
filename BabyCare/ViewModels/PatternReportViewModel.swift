import Foundation
import Security

@MainActor @Observable
final class PatternReportViewModel {
    var report: PatternReport?
    var aiInsight: String?
    var selectedPeriod: Period = .week
    var isLoading = false
    var isLoadingAI = false
    var errorMessage: String?

    // MARK: - Comparison
    var showComparison = false {
        didSet {
            if showComparison {
                Task { await loadComparison() }
            }
        }
    }
    var isLoadingComparison = false

    // MARK: - Feeding Prediction
    var feedingPredictionText: String?

    enum Period: String, CaseIterable {
        case week = "주간"
        case month = "월간"
    }

    private let firestoreService = FirestoreService.shared
    private var lastFetchedUserId: String?
    private var lastFetchedBabyId: String?
    private var lastFeedingActivity: Activity?

    private static let apiKeyKey = "ai_api_key"

    /// AI API 키 — Keychain 저장 (AIAdviceViewModel과 공유 키 + 동일 패턴).
    /// UserDefaults legacy 값이 있으면 자동으로 Keychain에 마이그레이션 후 제거.
    var apiKey: String {
        if let keychainValue = Self.loadFromKeychain(key: Self.apiKeyKey) {
            return keychainValue
        }
        if let legacyValue = UserDefaults.standard.string(forKey: Self.apiKeyKey),
           !legacyValue.isEmpty {
            Self.saveToKeychain(key: Self.apiKeyKey, value: legacyValue)
            UserDefaults.standard.removeObject(forKey: Self.apiKeyKey)
            return legacyValue
        }
        return ""
    }

    var hasAPIKey: Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Keychain Helpers (AIAdviceViewModel와 동일 패턴, 동일 키 공유)

    private static func saveToKeychain(key: String, value: String) {
        let data = value.data(using: .utf8)!
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                     kSecAttrAccount as String: key,
                                     kSecValueData as String: data]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    private static func loadFromKeychain(key: String) -> String? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                     kSecAttrAccount as String: key,
                                     kSecMatchLimit as String: kSecMatchLimitOne,
                                     kSecReturnData as String: true]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - Load Report

    func loadReport(userId: String, babyId: String) async {
        isLoading = true
        defer { isLoading = false }

        lastFetchedUserId = userId
        lastFetchedBabyId = babyId

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

            // 마지막 수유 기록 추출 (예측에 사용)
            lastFeedingActivity = activities
                .filter { $0.type.category == .feeding }
                .max(by: { $0.startTime < $1.startTime })

            // 수유 예측 텍스트 계산
            if let interval = report?.feeding.averageInterval {
                let estimate = FeedingPredictionService.nextEstimate(
                    lastFeeding: lastFeedingActivity,
                    averageInterval: interval
                )
                feedingPredictionText = FeedingPredictionService.predictionText(estimate: estimate)
            } else {
                feedingPredictionText = nil
            }

            // 기간 변경 시 이전 AI 분석 초기화
            aiInsight = nil
        } catch {
            errorMessage = "데이터를 불러오지 못했습니다."
            report = nil
            feedingPredictionText = nil
        }
    }

    // MARK: - Comparison

    func loadComparison() async {
        guard selectedPeriod == .week else { return }
        guard let report,
              let userId = lastFetchedUserId,
              let babyId = lastFetchedBabyId else { return }

        isLoadingComparison = true
        defer { isLoadingComparison = false }

        let calendar = Calendar.current
        let previousEnd = report.startDate
        let previousStart = calendar.date(byAdding: .day, value: -7, to: previousEnd) ?? previousEnd

        do {
            let previousActivities = try await firestoreService.fetchActivities(
                userId: userId, babyId: babyId,
                from: previousStart.startOfDay, to: previousEnd.endOfDay
            )

            self.report = PatternAnalysisService.analyzeComparison(
                currentReport: report,
                previousActivities: previousActivities,
                previousPeriod: (start: previousStart, end: previousEnd)
            )
        } catch {
            errorMessage = "비교 데이터를 불러오지 못했습니다."
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

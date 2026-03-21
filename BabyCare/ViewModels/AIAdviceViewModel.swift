import Foundation

@MainActor @Observable
final class AIAdviceViewModel {
    var messages: [ChatMessage] = []
    var inputText = ""
    var isLoading = false
    var errorMessage: String?

    private static let apiKeyKey = "ai_api_key"

    var apiKey: String {
        get { UserDefaults.standard.string(forKey: Self.apiKeyKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: Self.apiKeyKey) }
    }

    var hasAPIKey: Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    struct ChatMessage: Identifiable {
        let id = UUID()
        let role: Role
        let content: String
        let timestamp = Date()

        enum Role {
            case user, assistant
        }
    }

    // MARK: - Topics

    static let topics: [(icon: String, title: String, prompt: String)] = [
        ("cup.and.saucer.fill", "수유 조언", "신생아 수유에 대해 조언해주세요. 모유수유와 분유수유 팁을 알려주세요."),
        ("moon.zzz.fill", "수면 가이드", "아기 수면 교육과 수면 패턴에 대해 조언해주세요."),
        ("figure.2.and.child.holdinghands", "발달 상담", "아기 발달 이정표와 자극 놀이에 대해 알려주세요."),
        ("heart.text.clipboard.fill", "건강 정보", "아기 건강 관리와 일반적인 증상 대처법을 알려주세요."),
    ]

    private let baseSystemPrompt = """
    당신은 경험 많은 소아과 전문의이자 육아 상담가입니다.
    한국어로 답변하며, 아기를 키우는 부모에게 실용적이고 따뜻한 조언을 제공합니다.
    - 의학적으로 정확한 정보를 제공하세요.
    - 심각한 증상이 의심되면 반드시 병원 방문을 권유하세요.
    - 답변은 간결하고 읽기 쉽게 작성하세요.
    - 이모지를 적절히 사용해서 친근하게 답변하세요.
    """

    // MARK: - System Prompt Builder

    func buildSystemPrompt(baby: Baby?) -> String {
        guard let baby else { return baseSystemPrompt }
        let ageMonths = Calendar.current.dateComponents([.month], from: baby.birthDate, to: Date()).month ?? 0
        var context = "현재 상담 중인 아기 정보:\n"
        context += "- 이름: \(baby.name)\n"
        context += "- 나이: \(ageMonths)개월\n"
        context += "- 성별: \(baby.gender.displayName)\n"
        return baseSystemPrompt + "\n\n" + context
    }

    // MARK: - Send

    var currentBaby: Baby?

    func send(_ text: String? = nil) async {
        let content = text ?? inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        guard hasAPIKey else {
            errorMessage = "API 키를 먼저 설정해주세요."
            return
        }

        let userMessage = ChatMessage(role: .user, content: content)
        messages.append(userMessage)
        inputText = ""
        isLoading = true
        errorMessage = nil

        do {
            let apiMessages = messages.map {
                AIService.Message(
                    role: $0.role == .user ? "user" : "assistant",
                    content: $0.content
                )
            }

            let response = try await AIService.ask(
                messages: apiMessages,
                systemPrompt: buildSystemPrompt(baby: currentBaby),
                apiKey: apiKey
            )

            let filtered = AIGuardrailService.filter(response)
            messages.append(ChatMessage(role: .assistant, content: filtered))
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func clearChat() {
        messages.removeAll()
        errorMessage = nil
    }
}

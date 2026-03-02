import Foundation

/// Claude API를 통한 AI 육아 조언 서비스.
/// API 키는 앱 내 설정에서 사용자가 직접 입력.
enum AIService {
    private static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    struct Message: Codable, Sendable {
        let role: String
        let content: String
    }

    struct Response: Codable, Sendable {
        struct ContentBlock: Codable, Sendable {
            let type: String
            let text: String?
        }
        let content: [ContentBlock]
    }

    static func ask(
        messages: [Message],
        systemPrompt: String,
        apiKey: String
    ) async throws -> String {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 30

        let body: [String: Any] = [
            "model": "claude-haiku-4-5-20251001",
            "max_tokens": 1024,
            "system": systemPrompt,
            "messages": messages.map { ["role": $0.role, "content": $0.content] }
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 {
                throw AIError.invalidAPIKey
            }
            let errorBody = String(data: data, encoding: .utf8) ?? ""
            throw AIError.serverError(httpResponse.statusCode, errorBody)
        }

        let decoded = try JSONDecoder().decode(Response.self, from: data)
        return decoded.content.compactMap(\.text).joined()
    }

    enum AIError: LocalizedError {
        case invalidAPIKey
        case invalidResponse
        case serverError(Int, String)

        var errorDescription: String? {
            switch self {
            case .invalidAPIKey:
                return "API 키가 올바르지 않습니다. 설정에서 확인해주세요."
            case .invalidResponse:
                return "서버 응답을 처리할 수 없습니다."
            case .serverError(let code, _):
                return "서버 오류가 발생했습니다. (코드: \(code))"
            }
        }
    }
}

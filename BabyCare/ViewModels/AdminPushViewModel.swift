import Foundation

/// 관리자 푸시 발송 — 웹 관리자 서버(`/api/push`)에 로그인 표를 붙여 보낸다.
/// 앱에는 발송 키(서비스 계정)가 없고 넣어서도 안 된다. 서버가 관리자 계정인지 보고 보내며, 보낸 기록도 서버가 남긴다.
/// 🩸 2026-11-07 전에는 앱이 키 없이 발송 서버를 직접 불러 늘 실패했다.
@MainActor @Observable
final class AdminPushViewModel {
    typealias Transport = @Sendable (URLRequest) async throws -> (Data, URLResponse)

    nonisolated static let endpoint = URL(string: "https://babycare-admin.vercel.app/api/push")!
    nonisolated static let successMessage = "푸시 발송 성공"

    var isSending = false
    var resultMessage: String?

    private let transport: Transport

    init(transport: @escaping Transport = { try await URLSession.shared.data(for: $0) }) {
        self.transport = transport
    }

    /// 로그인 표를 받아 서버에 보내고, 결과 글을 `resultMessage` 에 둔다. 표를 못 받으면 서버에 묻지 않는다.
    func send(title: String, body: String, topic: String, idToken: () async throws -> String) async {
        isSending = true
        defer { isSending = false }
        do {
            let token = try await idToken()
            let request = try Self.request(title: title, body: body, topic: topic, idToken: token)
            let (data, response) = try await transport(request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            resultMessage = Self.resultMessage(status: status, data: data)
        } catch {
            resultMessage = "발송 실패: \(error.localizedDescription)"
        }
    }

    nonisolated static func request(title: String, body: String, topic: String, idToken: String) throws -> URLRequest {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(["title": title, "body": body, "topic": topic])
        return request
    }

    /// 2xx 면 성공. 아니면 서버가 준 까닭(`{"error": "…"}`)을, 없으면 응답 번호를 보여 준다.
    nonisolated static func resultMessage(status: Int, data: Data) -> String {
        if (200...299).contains(status) { return successMessage }
        if let reason = (try? JSONDecoder().decode(AdminPushRefusal.self, from: data))?.error, !reason.isEmpty {
            return "발송 실패: \(reason)"
        }
        return "발송 실패: 서버 응답 \(status)"
    }
}

/// 웹 관리자 서버가 거절할 때 돌려주는 몸통.
private struct AdminPushRefusal: Decodable {
    let error: String
}

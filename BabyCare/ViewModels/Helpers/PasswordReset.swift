import Foundation

/// 비밀번호 재설정 메일 보내기의 판단 한 곳.
/// 성공이면 nil, 실패면 화면에 띄울 문구를 돌려준다.
/// 🩸 2026-11-07 전에는 결과와 상관없이 「재설정 링크를 발송했습니다」가 떴다(실패 글은 뒤 로그인 화면에 샜다).
@MainActor
enum PasswordReset {
    static let blankAddressMessage = "이메일을 입력해주세요."

    static func send(
        to address: String,
        sender: (String) async throws -> Void,
        describe: (Error) -> String
    ) async -> String? {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return blankAddressMessage }
        do {
            try await sender(trimmed)
            return nil
        } catch {
            return describe(error)
        }
    }
}

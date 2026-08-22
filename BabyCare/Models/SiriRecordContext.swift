import Foundation

/// 시리(App Intents)로 들어온 기록의 저장 대상 — 소유자 경로와 아기.
///
/// 시리는 앱 화면 없이 백그라운드에서 실행되므로 ViewModel 상태를 믿을 수 없다.
/// 대신 앱이 App Group 에 남겨둔 스냅샷(소유자 uid · 아기 id)을 읽어 해석한다.
///
/// 🔒 공백/누락 uid 는 절대 통과시키지 않는다 — 통과하면 `users//babies/...` 같은
///    깨진 경로에 쓰게 되고, 소유자 격리(#41 · #49 owner-path 5종)가 무너진다.
enum SiriRecordContext: Equatable {
    case ready(ownerUserId: String, babyId: String, babyName: String?)
    case notReady(Reason)

    /// 기록할 수 없는 사유 — 시리 응답 문구가 여기서 갈린다.
    enum Reason: Equatable {
        case noAccount   // 로그인 정보 없음 (로그아웃/미로그인)
        case noBaby      // 선택된 아기 없음

        /// 시리가 하는 말 — "실패했어요"로 끝내지 않고 **무엇을 해야 하는지** 알려준다.
        var siriMessage: String {
            switch self {
            case .noAccount: "베이비케어에 먼저 로그인해 주세요"
            case .noBaby: "베이비케어에서 아기를 먼저 등록해 주세요"
            }
        }
    }

    static func resolve(ownerUserId: String?, babyId: String?, babyName: String?) -> SiriRecordContext {
        guard let owner = ownerUserId?.trimmingCharacters(in: .whitespacesAndNewlines),
              !owner.isEmpty else { return .notReady(.noAccount) }
        guard let baby = babyId?.trimmingCharacters(in: .whitespacesAndNewlines),
              !baby.isEmpty else { return .notReady(.noBaby) }

        let name = babyName?.trimmingCharacters(in: .whitespacesAndNewlines)
        return .ready(ownerUserId: owner, babyId: baby, babyName: (name?.isEmpty ?? true) ? nil : name)
    }
}

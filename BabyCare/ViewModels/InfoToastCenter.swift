import Foundation

/// 전역 인포 토스트 채널 (오프라인 저장 안내 등 정보성 문구 전용).
/// errorMessage 채널에 정보성 문구를 실으면 `errorMessage == nil` 성공 판정이 오염되고
/// "오류" 제목 alert로 표시된다 — 정보 안내는 이 별도 채널로만 흘린다 (UX Clean Sweep A3).
@MainActor @Observable
final class InfoToastCenter {
    static let shared = InfoToastCenter()

    init() {}

    private(set) var message: String?

    func show(_ text: String) {
        message = text
    }

    /// 자동 소거 — 표시 시점에 캡처한 문구와 현재 문구가 같을 때만 내린다
    /// (소거 대기 중 새 토스트가 뜬 경우 새 토스트를 유지).
    func dismiss(ifStillShowing shown: String) {
        if message == shown {
            message = nil
        }
    }

    /// 오프라인 저장 안내 단일 카피 (활동/일기/성장/건강 공용).
    func offlineSaved() {
        show("오프라인 저장됨 — 연결 시 자동 동기화")
    }
}

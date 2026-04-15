import Foundation

/// 신규 획득 배지 큐. BadgeEvaluator.evaluate() 결과를 받아 snackbar UI가 순차 표시할 수 있도록 공급.
/// UI 레이어(BadgeSnackbarView)는 `current`를 observe하고, 표시 종료 시 `dismiss()` 호출.
@MainActor
@Observable
final class BadgePresenter {
    private(set) var pending: [Badge] = []
    private(set) var current: Badge?

    func enqueue(_ badges: [Badge]) {
        guard !badges.isEmpty else { return }
        pending.append(contentsOf: badges)
        advanceIfIdle()
    }

    func dismiss() {
        guard current != nil else { return }
        current = nil
        advanceIfIdle()
    }

    private func advanceIfIdle() {
        guard current == nil, !pending.isEmpty else { return }
        current = pending.removeFirst()
    }
}

import Foundation
import Observation
import SwiftUI

/// 여행 공간 열기 — 아래 바 「여행」과 홈의 여행 카드가 같은 곳을 연다(설계 2026-11-05 §1).
@MainActor @Observable
final class TravelSpaceRouter {
    static let shared = TravelSpaceRouter()

    var isPresented = false
    /// 홈 카드에서 연 여행 — 없으면 다가오는 여행.
    private(set) var initialTripId: String?

    func open(tripId: String? = nil) {
        guard FeatureFlags.travelEnabled else { return }
        initialTripId = tripId
        withoutSlide { isPresented = true }
    }

    /// 베이비케어로 돌아가기(아래 바 「←」 · 딥링크·알림이 오면 먼저 닫는다).
    func close() {
        withoutSlide { isPresented = false }
    }

    /// 아래에서 올라오는 시트 움직임 없이 제자리에서 바꾼다(PO 참고 화면 2026-11-05).
    private func withoutSlide(_ change: () -> Void) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction, change)
    }
}

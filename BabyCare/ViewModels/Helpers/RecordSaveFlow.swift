import Foundation

/// 기록 저장 → (같은 종류 용품이 둘 이상이면) 「사용할 용품 선택」 → 끝(단추 멈춤 · 창 닫기 · 저장 안내).
///
/// `Saved` = 끝낼 때 넘길 값(통합 기록 시트는 저장한 기록 · 칸별 기록 화면은 `Void`).
struct RecordSaveFlow<Saved> {
    private(set) var isSaving = false
    private(set) var productCandidates: [BabyProduct] = []
    private var pending: Saved?

    var isPickingProduct: Bool { !productCandidates.isEmpty }

    mutating func begin() {
        isSaving = true
        productCandidates = []
        pending = nil
    }

    /// 저장이 실패했다 — 끝(안내 없이 단추만 멈춤).
    mutating func failed() {
        isSaving = false
        productCandidates = []
        pending = nil
    }

    /// 저장됐다. 고를 용품이 있으면 고르기로 가고 nil(아직 안 끝남), 없으면 끝 — 돌려준 값으로 끝을 알린다.
    mutating func saved(_ value: Saved, candidates: [BabyProduct]?) -> Saved? {
        if let candidates, !candidates.isEmpty {
            productCandidates = candidates
            pending = value
            return nil
        }
        isSaving = false
        pending = nil
        return value
    }

    /// 시트 바인딩이 닫을 때 — 고를 목록만 비운다(끝은 `pickerClosed`).
    mutating func dropCandidates() {
        productCandidates = []
    }

    /// 고르기 창이 닫혔다. RED 판: 고치기 전 동작 그대로 — 「건너뛰기」·내리기로 닫히면 끝나지 않는다.
    mutating func pickerClosed() -> Saved? {
        productCandidates = []
        return nil
    }
}

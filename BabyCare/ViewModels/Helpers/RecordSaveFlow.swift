import Foundation

/// 기록 저장 → (같은 종류 용품이 둘 이상이면) 「사용할 용품 선택」 → 끝(단추 멈춤 · 창 닫기 · 저장 안내).
///
/// `Saved` = 끝낼 때 넘길 값(통합 기록 시트는 저장한 기록 · 칸별 기록 화면은 `Void`).
struct RecordSaveFlow<Saved> {
    private(set) var isSaving = false
    private(set) var productCandidates: [BabyProduct] = []
    /// 고르기 창을 띄우나 — 목록과 따로 둔다(닫히며 내려가는 동안에도 목록은 그려져야 한다).
    private(set) var isPickingProduct = false
    private var pending: Saved?

    mutating func begin() {
        isSaving = true
        productCandidates = []
        isPickingProduct = false
        pending = nil
    }

    /// 저장이 실패했다 — 끝(안내 없이 단추만 멈춤).
    mutating func failed() {
        isSaving = false
        productCandidates = []
        isPickingProduct = false
        pending = nil
    }

    /// 저장됐다. 고를 용품이 있으면 고르기로 가고 nil(아직 안 끝남), 없으면 끝 — 돌려준 값으로 끝을 알린다.
    mutating func saved(_ value: Saved, candidates: [BabyProduct]?) -> Saved? {
        if let candidates, !candidates.isEmpty {
            productCandidates = candidates
            isPickingProduct = true
            pending = value
            return nil
        }
        isSaving = false
        pending = nil
        return value
    }

    /// 시트 바인딩이 닫기 시작할 때 — 띄움만 끈다. 목록은 다 닫힌 뒤(`pickerClosed`) 비운다
    /// (먼저 비우면 닫히며 내려가는 동안 빈 목록이 비친다 · 2026-11-14 검토).
    mutating func dismissPicker() {
        isPickingProduct = false
    }

    /// 고르기 창이 닫혔다 — 골랐든 「건너뛰기」든 아래로 내렸든. 저장 중이었으면 끝(저장한 값을 돌려준다),
    /// 이미 끝났거나 저장 중이 아니면 nil(끝은 한 번만).
    mutating func pickerClosed() -> Saved? {
        isPickingProduct = false
        productCandidates = []
        guard isSaving, let value = pending else { return nil }
        isSaving = false
        pending = nil
        return value
    }
}

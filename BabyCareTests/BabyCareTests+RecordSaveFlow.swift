import XCTest
@testable import BabyCare

/// 기록 저장 → 용품 고르기 → 끝. 어느 길로 닫히든 끝은 한 번만.
/// 고치기 전: 끝이 「용품을 골랐을 때」에만 있어 「건너뛰기」나 창 내리기 뒤엔 저장은 됐는데 단추가 계속 돌았다
/// (기록 화면 4곳 — 통합 시트·수유·기저귀·건강 — 이 같은 코드를 복사해 같이 틀렸다).
final class RecordSaveFlowTests: XCTestCase {

    private let diapers = [
        BabyProduct(name: "기저귀 A", category: .diaper),
        BabyProduct(name: "기저귀 B", category: .diaper),
    ]

    /// 고를 용품이 없으면 저장하자마자 끝.
    func test_noProductToPick_finishesRightAfterSaving() {
        var flow = RecordSaveFlow<String>()
        flow.begin()
        XCTAssertEqual(flow.saved("기록1", candidates: nil), "기록1")
        XCTAssertFalse(flow.isSaving)
        XCTAssertFalse(flow.isPickingProduct)

        flow.begin()
        XCTAssertEqual(flow.saved("기록2", candidates: []), "기록2", "빈 목록도 고를 것 없음")
        XCTAssertFalse(flow.isSaving)
    }

    /// 고를 용품이 있으면 고르기 창으로 가고 아직 끝나지 않는다.
    func test_productsToPick_waitForThePicker() {
        var flow = RecordSaveFlow<String>()
        flow.begin()
        XCTAssertNil(flow.saved("기록1", candidates: diapers))
        XCTAssertTrue(flow.isSaving)
        XCTAssertTrue(flow.isPickingProduct)
        XCTAssertEqual(flow.productCandidates.map(\.name), ["기저귀 A", "기저귀 B"])
    }

    /// 「건너뛰기」·창 내리기·골라서 닫기 — 어느 길이든 창이 닫히면 저장한 그 기록으로 끝난다.
    func test_pickerClosedAnyWay_finishesWithTheSavedRecord() {
        var flow = RecordSaveFlow<String>()
        flow.begin()
        _ = flow.saved("방금 저장한 기록", candidates: diapers)
        flow.dismissPicker() // 시트 바인딩이 닫기 시작함
        XCTAssertFalse(flow.isPickingProduct, "닫기 시작하면 띄움은 끈다")
        // 닫히며 내려가는 동안에도 창이 그려진다 — 목록을 먼저 비우면 빈 목록이 비친다(2026-11-14 검토)
        XCTAssertEqual(flow.productCandidates.map(\.name), ["기저귀 A", "기저귀 B"], "닫히는 동안 목록이 비었다")

        XCTAssertEqual(flow.pickerClosed(), "방금 저장한 기록")
        XCTAssertFalse(flow.isSaving, "단추가 계속 돌면 안 된다")
        XCTAssertFalse(flow.isPickingProduct)
        XCTAssertTrue(flow.productCandidates.isEmpty, "닫힌 뒤엔 비운다")
    }

    /// 끝은 한 번만 — 창이 닫힌 알림이 두 번 와도 두 번 끝내지 않는다(안내가 두 번 뜨지 않게).
    func test_pickerClosedTwice_finishesOnce() {
        var flow = RecordSaveFlow<String>()
        flow.begin()
        _ = flow.saved("기록1", candidates: diapers)
        XCTAssertEqual(flow.pickerClosed(), "기록1")
        XCTAssertNil(flow.pickerClosed())
    }

    /// 저장 중이 아닐 때 닫힘 알림이 오면 아무것도 끝내지 않는다.
    func test_pickerClosedWhileNotSaving_isIgnored() {
        var flow = RecordSaveFlow<String>()
        XCTAssertNil(flow.pickerClosed())
        XCTAssertFalse(flow.isSaving)
    }

    func test_failedSave_stopsWithoutFinishing() {
        var flow = RecordSaveFlow<String>()
        flow.begin()
        flow.failed()
        XCTAssertFalse(flow.isSaving)
        XCTAssertNil(flow.pickerClosed())
    }

    /// 칸별 기록 화면은 넘길 값이 없다(Void) — 그래도 끝은 알린다.
    func test_voidFlow_stillFinishesOnPickerClose() {
        var flow = RecordSaveFlow<Void>()
        flow.begin()
        XCTAssertNil(flow.saved((), candidates: diapers))
        XCTAssertNotNil(flow.pickerClosed())
        XCTAssertFalse(flow.isSaving)
    }
}

import XCTest
@testable import BabyCare

/// 할 일 화면의 칸 나누기 — 한 할 일은 한 칸에만.
/// 고치기 전: 「지연됨」 칸은 「할 일」 칸의 일부를 다시 뽑아, 지연된 할 일이 두 칸에 두 번 나왔다(「할 일 (N)」 수에도 들어갔다).
final class TodoSectionsTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func todo(_ title: String, dueIn hours: Double?) -> TodoItem {
        TodoItem(title: title, dueDate: hours.map { now.addingTimeInterval($0 * 3600) })
    }

    /// 지연된 것은 「지연됨」에만, 나머지(기한 전 · 기한 없음)는 「할 일」에만 — 두 칸을 합치면 빠짐도 겹침도 없다.
    func test_partition_putsEachTodoInExactlyOneSection() {
        let late = todo("어제까지", dueIn: -24)
        let soon = todo("내일까지", dueIn: 24)
        let open = todo("기한 없음", dueIn: nil)

        let sections = TodoViewModel.partition([late, soon, open], now: now)

        XCTAssertEqual(sections.overdue.map(\.title), ["어제까지"])
        XCTAssertEqual(sections.upcoming.map(\.title), ["내일까지", "기한 없음"])
    }

    /// 경계: 기한이 지금보다 1초라도 지났으면 지연, 아직이면 할 일.
    func test_partition_boundaryAtNow() {
        let justLate = todo("방금 지남", dueIn: -1.0 / 3600)
        let justAhead = todo("곧", dueIn: 1.0 / 3600)

        let sections = TodoViewModel.partition([justLate, justAhead], now: now)

        XCTAssertEqual(sections.overdue.map(\.title), ["방금 지남"])
        XCTAssertEqual(sections.upcoming.map(\.title), ["곧"])
    }

    /// 넣은 순서(기한 순 정렬)를 칸 안에서도 지킨다.
    func test_partition_keepsOrderWithinEachSection() {
        let late2 = todo("이틀 전", dueIn: -48)
        let late1 = todo("하루 전", dueIn: -24)
        let soon1 = todo("한 시간 뒤", dueIn: 1)
        let soon2 = todo("하루 뒤", dueIn: 24)

        let sections = TodoViewModel.partition([late2, late1, soon1, soon2], now: now)

        XCTAssertEqual(sections.overdue.map(\.title), ["이틀 전", "하루 전"])
        XCTAssertEqual(sections.upcoming.map(\.title), ["한 시간 뒤", "하루 뒤"])
    }
}

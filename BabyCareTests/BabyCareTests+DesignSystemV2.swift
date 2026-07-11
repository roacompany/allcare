import XCTest
import SwiftUI
@testable import BabyCare

/// Track A 가드 (Phase 0c) — DS2 정리 리팩토링이 토큰값/컴포넌트 구조를 silent 변경하지 못하게 박제.
/// 스냅샷 라이브러리 없음(project.yml = Firebase+Sentry only) → 토큰값 단언 + 구성(compile) 가드로 보호.
/// 계획: docs/superpowers/specs/2026-06-09-track-a-ds2-cleanup.md / 인벤토리: DesignSystemV2/DESIGN.md
final class DesignSystemV2Tests: XCTestCase {

    // MARK: - Token Scale Lock (cleanup이 값을 silent 변경 못하게 박제)

    func testDS2_spacingScale() {
        XCTAssertEqual(DS2.Spacing.xs, 4)
        XCTAssertEqual(DS2.Spacing.sm, 8)
        XCTAssertEqual(DS2.Spacing.md, 12)
        XCTAssertEqual(DS2.Spacing.lg, 16)
        XCTAssertEqual(DS2.Spacing.xl, 24)
        XCTAssertEqual(DS2.Spacing.xxl, 32)
    }

    func testDS2_radiusScale() {
        // ⚠️ DESIGN.md §1.1: DS2 sm=12 는 babycare-tokens.json sm=8 과 의도적 충돌(subset, PO 결정).
        XCTAssertEqual(DS2.Radius.sm, 12)
        XCTAssertEqual(DS2.Radius.md, 16)
        XCTAssertEqual(DS2.Radius.lg, 24)
    }

    func testDS2_shadowScale() {
        XCTAssertEqual(DS2.Shadow.sm.radius, 4)
        XCTAssertEqual(DS2.Shadow.md.radius, 8)
        XCTAssertEqual(DS2.Shadow.lg.radius, 16)
    }

    // MARK: - Component Structural Smoke (init 시그니처 깨지면 컴파일 실패 = 가드)

    @MainActor
    func testDS2_componentsConstruct() {
        _ = DS2Button("등록", icon: "plus", style: .primary) {}
        _ = DS2Button("취소", style: .secondary) {}
        _ = DS2Card { Text("x") }
        _ = DS2Section("제목") { Text("x") }
        _ = HealthStyleFavoriteCard(icon: "drop.fill", title: "유축", value: "120", unit: "ml", supporting: nil, tint: .purple)
        XCTAssertTrue(true, "DS2 컴포넌트 init 구조 가드 — 시그니처 변경 시 이 테스트가 컴파일 실패")
    }
}

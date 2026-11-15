import XCTest
@testable import BabyCare

/// 관리자(babycare-admin) 「콘텐츠 관리」는 이 스냅숏을 바이트 그대로 복사해 보여 준다 — 고객이 앱에서 보는 이유식 가이드 · 발달 콘텐츠 글과 같게.
/// 고치기 전(2026-11-15): 관리자 화면은 3월부터 앱과 다른 글을 「현재 콘텐츠는 앱에 하드코딩되어 있습니다」 안내와 함께 보여 줬다
/// (레시피 제목 17 중 0 · 발달 본문 18 중 0 같음 · 앱 첫 단계 이름의 「WHO 6개월 권장」과 꿀 경고가 관리자엔 없었다).
/// 앱 글을 바꾸면 여기가 빨개진다 → ① `bash scripts/record_admin_content_snapshot.sh` 로 스냅숏을 새로 쓰고(시뮬레이터 없이 맥에서 ·
/// 또는 `TEST_RUNNER_RECORD_ADMIN_CONTENT_SNAPSHOT=1 make test`) ② babycare-admin 에서 `npm run content:sync` 로 관리자 글도 맞춘다(설계: babycare-admin 설계서 §2-7).
/// 판정은 「내용이 같은가」 — 스냅숏을 쓴 기계(맥)와 견주는 기계(CI 의 아이폰)의 인코더 모양(빈칸 · 줄바꿈)이 달라도 글이 같으면 통과한다.
final class AdminContentSnapshotTests: XCTestCase {

    // MARK: 스냅숏 모양 — 관리자가 보여 주는 것만(단계 부제 · 개월 글 · 분류 그림 글자는 관리자가 안 보여 줘서 뺀다)

    private struct Snapshot: Codable, Equatable {
        let note: String
        let babyFood: BabyFood
        let development: Development

        enum CodingKeys: String, CodingKey {
            case note = "_note"
            case babyFood
            case development
        }
    }

    private struct BabyFood: Codable, Equatable {
        let disclaimer: String
        let honeyWarning: String
        let screen: ScreenText
        let stages: [Stage]
        let recipes: [Recipe]
    }

    /// 앱 화면 코드에 글자로 박힌 글(모델에 없음) — 관리자가 그대로 보여 준다.
    private struct ScreenText: Codable, Equatable {
        let disclaimerTitle: String
        let honeyTitle: String
        let allergyTitle: String
        let allergyNotice: String
        let firstFeedingNote: String
    }

    private struct Stage: Codable, Equatable {
        let key: String
        let title: String
    }

    private struct Recipe: Codable, Equatable {
        let id: String
        let stage: String
        let title: String
        let description: String
        let ingredients: [String]
        let steps: [String]
        let allergyWarnings: [String]
    }

    private struct Development: Codable, Equatable {
        let categories: [Category]
        let cards: [Card]
    }

    private struct Category: Codable, Equatable {
        let key: String
        let label: String
    }

    private struct Card: Codable, Equatable {
        let id: String
        let category: String
        let title: String
        let body: String
        let monthRange: [Int]
        let emoji: String
    }

    private static let note = "앱(BabyCare) 이유식 가이드 · 발달 콘텐츠 글 — AdminContentSnapshotTests 가 앱 값으로 쓴다. 손으로 고치지 말 것. 관리자(babycare-admin)는 이 파일을 그대로 복사해 보여 준다(npm run content:sync)."
    private static let recordKey = "RECORD_ADMIN_CONTENT_SNAPSHOT"
    private static let missingMessage = "관리자 콘텐츠 스냅숏 파일이 없습니다 — bash scripts/record_admin_content_snapshot.sh 로 만드세요(또는 TEST_RUNNER_RECORD_ADMIN_CONTENT_SNAPSHOT=1 make test)"
    private static let fixSteps = "앱 글을 일부러 바꿨다면 ① bash scripts/record_admin_content_snapshot.sh 로 스냅숏을 새로 쓰고(또는 TEST_RUNNER_RECORD_ADMIN_CONTENT_SNAPSHOT=1 make test) ② babycare-admin 에서 npm run content:sync 로 관리자 글도 맞추세요"
    /// 시뮬레이터 시험은 맥의 소스 폴더를 그대로 읽고 쓴다 — 시험 파일 옆 Fixtures/(링크로 불러도 저장소의 진짜 자리로).
    private static let snapshotURL = URL(fileURLWithPath: #filePath)
        .resolvingSymlinksInPath()
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures/app-content.json")

    /// 앱 화면 코드에 글자로 박힌 글 — 모델에 없어 여기 적는다. `test_screenTexts_stillInAppScreens` 가 화면 파일에 같은 글이 그대로 있는지 대조한다.
    private static let screenText = ScreenText(
        disclaimerTitle: "소아과 상담 권고",
        honeyTitle: "꿀 경고",
        allergyTitle: "알레르기 주의",
        allergyNotice: "새로운 식재료는 하나씩 4~5일 간격으로 도입하세요. 발진, 두드러기, 구토 등의 증상이 나타나면 즉시 중단하고 소아과에 방문하세요.",
        firstFeedingNote: "처음 먹일 때는 소량부터 시작하고 4~5일 후 반응을 확인하세요."
    )
    /// 저장소 맨 위 — 화면 파일을 읽는다(링크로 불러도 진짜 자리로).
    private static let repoRoot = URL(fileURLWithPath: #filePath)
        .resolvingSymlinksInPath()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    /// 지금 앱 값 — 순서는 앱 순서 그대로 · 단계 · 분류 키는 case 이름.
    private static func current() -> Snapshot {
        Snapshot(
            note: note,
            babyFood: BabyFood(
                disclaimer: BabyFoodGuideData.disclaimerText,
                honeyWarning: BabyFoodGuideData.honeyWarning,
                screen: screenText,
                stages: BabyFoodStage.allCases.map { Stage(key: String(describing: $0), title: $0.title) },
                recipes: BabyFoodGuideData.allRecipes.map {
                    Recipe(id: $0.id, stage: String(describing: $0.stage), title: $0.title, description: $0.description,
                           ingredients: $0.ingredients, steps: $0.steps, allergyWarnings: $0.allergyWarnings)
                }
            ),
            development: Development(
                categories: DevelopmentCategory.allCases.map { Category(key: String(describing: $0), label: $0.rawValue) },
                cards: DevelopmentCard.all.map {
                    Card(id: $0.id, category: String(describing: $0.category), title: $0.title, body: $0.body,
                         monthRange: [$0.monthRange.lowerBound, $0.monthRange.upperBound], emoji: $0.emoji)
                }
            )
        )
    }

    private static func encoded(_ snapshot: Snapshot) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        var data = try encoder.encode(snapshot)
        data.append(0x0A)
        return data
    }

    /// 저장본이 지금 앱 값과 내용이 같은가(글 모양은 안 본다).
    private static func matches(saved: Data, current: Snapshot) -> Bool {
        (try? JSONDecoder().decode(Snapshot.self, from: saved)) == current
    }

    /// 첫 다른 줄 — 번호(1부터)와 두 줄(각 120자까지).
    private static func firstDifference(saved: String, now: String) -> String {
        let a = saved.components(separatedBy: "\n")
        let b = now.components(separatedBy: "\n")
        var i = 0
        while i < a.count, i < b.count, a[i] == b[i] { i += 1 }
        func line(_ lines: [String]) -> String { i < lines.count ? String(lines[i].prefix(120)) : "(없음)" }
        return "\(i + 1)번째 줄 — 스냅숏: \(line(a)) / 지금 앱: \(line(b))"
    }

    /// 스냅숏 파일의 내용이 지금 앱 값과 같다. 기록 모드는 쓰고 나서 늘 실패로 끝난다(CI 에서 조용히 통과하지 않게).
    func test_snapshot_matchesAppContent() throws {
        let current = Self.current()
        let now = try Self.encoded(current)
        if ProcessInfo.processInfo.environment[Self.recordKey] == "1" {
            try FileManager.default.createDirectory(at: Self.snapshotURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try now.write(to: Self.snapshotURL)
            XCTFail("관리자 콘텐츠 스냅숏을 새로 썼습니다 — 기록을 끄고 다시 돌리세요. babycare-admin 에서 npm run content:sync 도 하세요")
            return
        }
        guard let saved = try? Data(contentsOf: Self.snapshotURL) else {
            XCTFail(Self.missingMessage)
            return
        }
        guard !Self.matches(saved: saved, current: current) else { return }
        // 다름 — 저장본을 지금 모양으로 다시 써서 견준다(기계마다 다른 빈칸 · 줄바꿈이 아니라 글이 다른 자리를 가리키게).
        let savedNow = (try? JSONDecoder().decode(Snapshot.self, from: saved)).flatMap { try? Self.encoded($0) } ?? saved
        let where_ = Self.firstDifference(saved: String(decoding: savedNow, as: UTF8.self), now: String(decoding: now, as: UTF8.self))
        XCTFail("""
        이유식 · 발달 콘텐츠 글이 관리자 스냅숏과 다릅니다 — \(where_)
        \(Self.fixSteps)
        """)
    }

    /// 관리자가 그대로 보여 주는 앱 화면 글(이유식 가이드 상자 제목 셋 · 알레르기 안내 · 레시피 화면 한 줄)이 앱 화면 파일에 그대로 있다 —
    /// 화면 글을 바꾸면 여기가 빨개진다(이 시험의 screenText 를 같은 글로 고치고 → 스냅숏 다시 쓰기 → 관리자 content:sync).
    func test_screenTexts_stillInAppScreens() throws {
        let views = Self.repoRoot.appendingPathComponent("BabyCare/Views/BabyFood")
        let guide = try String(contentsOf: views.appendingPathComponent("BabyFoodGuideView.swift"), encoding: .utf8)
        let detail = try String(contentsOf: views.appendingPathComponent("BabyFoodRecipeDetailView.swift"), encoding: .utf8)
        let t = Self.screenText
        let expected: [(text: String, source: String, file: String)] = [
            (t.disclaimerTitle, guide, "BabyFoodGuideView.swift"),
            (t.honeyTitle, guide, "BabyFoodGuideView.swift"),
            (t.allergyTitle, guide, "BabyFoodGuideView.swift"),
            (t.allergyNotice, guide, "BabyFoodGuideView.swift"),
            (t.firstFeedingNote, detail, "BabyFoodRecipeDetailView.swift"),
        ]
        for e in expected {
            XCTAssertTrue(e.source.contains("Text(\"\(e.text)\")"),
                          "관리자가 그대로 보여 주는 앱 화면 글 「\(e.text)」이 \(e.file) 에 없습니다 — 화면 글을 바꿨다면 이 시험의 screenText 를 같은 글로 고치고, \(Self.fixSteps)")
        }
    }

    /// 같은 내용이면 글 모양(빈칸 · 줄바꿈 · 키 순서)이 달라도 같다 — 스냅숏을 쓴 기계(맥)와 견주는 기계(CI 의 아이폰)의 인코더 모양이 달라도 빨개지지 않게.
    func test_sameContentInAnotherFormat_matches() throws {
        let current = Self.current()
        let compact = JSONEncoder() // 빈칸 · 줄바꿈 없음 · 키 순서도 구조체 순서
        XCTAssertTrue(Self.matches(saved: try compact.encode(current), current: current))
        let changed = Snapshot(note: current.note + "!", babyFood: current.babyFood, development: current.development)
        XCTAssertFalse(Self.matches(saved: try compact.encode(changed), current: current))
    }

    /// 스냅숏이 앱의 단계 · 레시피 · 분류 · 카드를 하나도 빠뜨리지 않는다(순서 포함) — 형식을 고치다 한 묶음을 빼먹으면 여기서 잡힌다.
    func test_snapshot_coversEveryStageRecipeCategoryAndCard() throws {
        guard let saved = try? Data(contentsOf: Self.snapshotURL) else {
            XCTFail(Self.missingMessage)
            return
        }
        let snapshot = try JSONDecoder().decode(Snapshot.self, from: saved)
        XCTAssertEqual(snapshot.babyFood.stages.map(\.key), BabyFoodStage.allCases.map { String(describing: $0) })
        XCTAssertEqual(snapshot.babyFood.recipes.map(\.id), BabyFoodGuideData.allRecipes.map(\.id))
        XCTAssertEqual(snapshot.development.categories.map(\.key), DevelopmentCategory.allCases.map { String(describing: $0) })
        XCTAssertEqual(snapshot.development.cards.map(\.id), DevelopmentCard.all.map(\.id))
    }
}

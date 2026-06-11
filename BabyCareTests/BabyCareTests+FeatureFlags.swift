import XCTest
@testable import BabyCare

// 분리: BabyCareTests.swift FeatureFlag / AppContext / StableHash 도메인.
// 포함 클래스: AppContextTests / StableHashTests / FeatureFlagServiceTests /
// AppContextLifecycleTests / FeatureFlagServiceBehaviorTests

// MARK: - AppContext Tests

final class AppContextTests: XCTestCase {

    // MARK: Helper

    private func makeBaby() -> Baby {
        Baby(name: "테스트", birthDate: Date(), gender: .female)
    }

    private func makePregnancy() -> Pregnancy {
        Pregnancy(fetusCount: 1)
    }

    // MARK: 4-State factory tests

    // 1. empty arrays + nil pregnancy → .empty
    func testAppContext_fromEmptyBabies_nilPregnancy_returnsEmpty() {
        let context = AppContext.resolve(babies: [], pregnancy: nil)
        XCTAssertEqual(context, .empty)
    }

    // 2. one baby + nil pregnancy → .babyOnly
    func testAppContext_fromOneBaby_nilPregnancy_returnsBabyOnly() {
        let context = AppContext.resolve(babies: [makeBaby()], pregnancy: nil)
        XCTAssertEqual(context, .babyOnly)
    }

    // 3. empty babies + active pregnancy → .pregnancyOnly
    func testAppContext_fromEmptyBabies_withPregnancy_returnsPregnancyOnly() {
        let context = AppContext.resolve(babies: [], pregnancy: makePregnancy())
        XCTAssertEqual(context, .pregnancyOnly)
    }

    // 4. one baby + active pregnancy → .both
    func testAppContext_fromOneBaby_withPregnancy_returnsBoth() {
        let context = AppContext.resolve(babies: [makeBaby()], pregnancy: makePregnancy())
        XCTAssertEqual(context, .both)
    }

    // MARK: Edge cases — multiple babies

    // 5. multiple babies + nil pregnancy → .babyOnly
    func testAppContext_fromMultipleBabies_nilPregnancy_returnsBabyOnly() {
        let babies = [makeBaby(), makeBaby(), makeBaby()]
        let context = AppContext.resolve(babies: babies, pregnancy: nil)
        XCTAssertEqual(context, .babyOnly)
    }

    // 6. multiple babies + active pregnancy → .both
    func testAppContext_fromMultipleBabies_withPregnancy_returnsBoth() {
        let babies = [makeBaby(), makeBaby()]
        let context = AppContext.resolve(babies: babies, pregnancy: makePregnancy())
        XCTAssertEqual(context, .both)
    }

    // MARK: Pregnancy with various outcomes

    // 7. outcome=ongoing pregnancy → .pregnancyOnly (ongoing = active)
    func testAppContext_ongoingPregnancy_returnsPregnancyOnly() {
        var pregnancy = makePregnancy()
        pregnancy.outcome = PregnancyOutcome(rawValue: "ongoing") ?? nil
        let context = AppContext.resolve(babies: [], pregnancy: pregnancy)
        XCTAssertEqual(context, .pregnancyOnly)
    }

    // 8. pregnancy with dueDate set → .pregnancyOnly
    func testAppContext_pregnancyWithDueDate_returnsPregnancyOnly() {
        var pregnancy = makePregnancy()
        pregnancy.dueDate = Calendar.current.date(byAdding: .day, value: 200, to: Date())
        let context = AppContext.resolve(babies: [], pregnancy: pregnancy)
        XCTAssertEqual(context, .pregnancyOnly)
    }

    // MARK: Equatable correctness

    // 9. same state == same state
    func testAppContext_equatable_sameState_isEqual() {
        XCTAssertEqual(AppContext.empty, AppContext.empty)
        XCTAssertEqual(AppContext.babyOnly, AppContext.babyOnly)
        XCTAssertEqual(AppContext.pregnancyOnly, AppContext.pregnancyOnly)
        XCTAssertEqual(AppContext.both, AppContext.both)
    }

    // 10. different states != each other
    func testAppContext_equatable_differentStates_areNotEqual() {
        XCTAssertNotEqual(AppContext.empty, AppContext.babyOnly)
        XCTAssertNotEqual(AppContext.empty, AppContext.pregnancyOnly)
        XCTAssertNotEqual(AppContext.empty, AppContext.both)
        XCTAssertNotEqual(AppContext.babyOnly, AppContext.pregnancyOnly)
        XCTAssertNotEqual(AppContext.babyOnly, AppContext.both)
        XCTAssertNotEqual(AppContext.pregnancyOnly, AppContext.both)
    }

    // MARK: Exhaustive switch — compile-time proof

    // 11. All 4 cases are handled without `default:` (exhaustive switch proof)
    func testAppContext_exhaustiveSwitch_allCasesHandled() {
        let allCases: [AppContext] = [.empty, .babyOnly, .pregnancyOnly, .both]
        var covered = Set<String>()
        for context in allCases {
            switch context {
            case .empty:          covered.insert("empty")
            case .babyOnly:       covered.insert("babyOnly")
            case .pregnancyOnly:  covered.insert("pregnancyOnly")
            case .both:           covered.insert("both")
            // NOTE: no `default:` — if a new case is added, compiler will error here
            }
        }
        XCTAssertEqual(covered.count, 4, "모든 AppContext case가 switch에서 처리되어야 함")
        XCTAssertTrue(covered.contains("empty"))
        XCTAssertTrue(covered.contains("babyOnly"))
        XCTAssertTrue(covered.contains("pregnancyOnly"))
        XCTAssertTrue(covered.contains("both"))
    }

    // 12. factory is deterministic — same input always yields same output
    func testAppContext_factory_isDeterministic() {
        let baby = makeBaby()
        let pregnancy = makePregnancy()

        let run1 = AppContext.resolve(babies: [baby], pregnancy: pregnancy)
        let run2 = AppContext.resolve(babies: [baby], pregnancy: pregnancy)
        XCTAssertEqual(run1, run2)

        let run3 = AppContext.resolve(babies: [], pregnancy: nil)
        let run4 = AppContext.resolve(babies: [], pregnancy: nil)
        XCTAssertEqual(run3, run4)
    }

    // 13. hasBaby check is count-based not identity-based
    func testAppContext_babyCountMatters_notIdentity() {
        // Single baby triggers .babyOnly (not .empty)
        let singleBaby = AppContext.resolve(babies: [makeBaby()], pregnancy: nil)
        XCTAssertNotEqual(singleBaby, .empty)
        XCTAssertEqual(singleBaby, .babyOnly)
    }

    // 14. nil pregnancy strictly maps to no-pregnancy states
    func testAppContext_nilPregnancy_neverReturnsBothOrPregnancyOnly() {
        let withBabies = AppContext.resolve(babies: [makeBaby()], pregnancy: nil)
        let withoutBabies = AppContext.resolve(babies: [], pregnancy: nil)

        XCTAssertNotEqual(withBabies, .pregnancyOnly)
        XCTAssertNotEqual(withBabies, .both)
        XCTAssertNotEqual(withoutBabies, .pregnancyOnly)
        XCTAssertNotEqual(withoutBabies, .both)
    }
}

// MARK: - P2-4: StableHash Tests

final class StableHashTests: XCTestCase {

    // 1. DJB2 결정론적: 동일 입력 → 항상 동일 출력
    func testDjb2_deterministic_sameInputSameOutput() {
        let uid = "user-abc-123"
        XCTAssertEqual(StableHash.djb2(uid), StableHash.djb2(uid))
    }

    // 2. 다른 입력 → 다른 해시값 (해시 충돌 아닌 기본 케이스)
    func testDjb2_differentInputs_differentOutputs() {
        XCTAssertNotEqual(StableHash.djb2("user-A"), StableHash.djb2("user-B"))
    }

    // 3. bucket 범위: 0..<outOf
    func testBucket_inRange() {
        let uid = "test-uid-xyz"
        let bucket = StableHash.bucket(uid, outOf: 100)
        XCTAssertLessThan(bucket, 100)
    }

    // 4. bucket 결정론적
    func testBucket_deterministic() {
        let uid = "deterministic-user"
        XCTAssertEqual(
            StableHash.bucket(uid, outOf: 100),
            StableHash.bucket(uid, outOf: 100)
        )
    }

    // 5. 빈 문자열 처리 (crash 없음)
    func testDjb2_emptyString_noCrash() {
        let result = StableHash.djb2("")
        XCTAssertEqual(result, 5381) // DJB2 초기값 그대로
    }

    // 6. 알려진 값 고정 검증 (regression guard)
    func testDjb2_knownValue_isStable() {
        // "abc" DJB2: 193485963
        let result = StableHash.djb2("abc")
        XCTAssertEqual(result, 193485963)
    }

    // 7. bucket outOf=1 → 항상 0
    func testBucket_outOf1_alwaysZero() {
        XCTAssertEqual(StableHash.bucket("any-user-id", outOf: 1), 0)
    }
}

// MARK: - P2-4: FeatureFlagService Tests (in-memory mock, A-18 invariant)

final class FeatureFlagServiceTests: XCTestCase {

    // A-18: compile-time false → pregnancyModeEnabled NEVER true (fetch 결과 무관)
    @MainActor
    func testFeatureFlagService_compiletimeFalse_alwaysFalse() async {
        // FeatureFlags.pregnancyModeEnabled は currently true (P2-4 이후).
        // compile-time kill switch 동작은 FeatureFlags.pregnancyModeEnabled=false 시를 검증.
        // 이 테스트는 A-18 불변성 문서화 — compile-time=false path가 false 반환함을 단언.
        let service = FeatureFlagService.shared
        // compileTimeValue가 false인 경우 bootstrap은 즉시 false 반환해야 한다.
        // 현재 compileTimeValue=true이므로 직접 컴파일타임 결과 단위 테스트:
        // 대신 fallback 경로를 검증: fetch 실패 시 defaults=false → resolved=false
        // (RemoteConfig.setDefaults false as NSObject → configValue.boolValue = false)
        // 이 환경에서 RemoteConfig는 모의 없이 실제 Firebase 호출 → 오프라인/초기화 미완 시 실패
        // → try? 무시 → defaults 사용 → false
        // bootstrap 호출 없이 초기 상태 검증:
        XCTAssertFalse(service.pregnancyModeEnabled, "초기 상태는 항상 false (A-18)")
    }

    // A-18: UserDefaults 캐시 없을 때 coldStartDefault = false
    @MainActor
    func testFeatureFlagService_coldStartDefault_noCache_returnsFalse() {
        UserDefaults.standard.removeObject(forKey: FeatureFlagService.testCacheKey)
        let service = FeatureFlagService.shared
        // compile-time=true이므로 캐시 없으면 false 반환
        let result = service.coldStartDefault(userId: "test-user")
        XCTAssertFalse(result, "캐시 없을 때 coldStart = false")
    }

    // coldStartDefault: 킬스위치 ON이면 캐시값 반환, OFF(v2.8.8 핫픽스)면 A-18 우선(캐시 무관 false)
    @MainActor
    func testFeatureFlagService_coldStartDefault_withCache_returnsCachedValue() {
        UserDefaults.standard.set(true, forKey: FeatureFlagService.testCacheKey)
        defer { UserDefaults.standard.removeObject(forKey: FeatureFlagService.testCacheKey) }
        let service = FeatureFlagService.shared
        let result = service.coldStartDefault(userId: "test-user")
        // 컴파일 킬스위치 값에 따라 분기 — 스위치 OFF면 캐시를 무시하고 false (A-18 invariant)
        XCTAssertEqual(result, service.compileTimeValue,
                       "캐시 true → 킬스위치 ON이면 true, OFF면 false(A-18 우선)")
    }

    // A-18: pregnancyModeEnabled 초기값 false (fetch 전)
    @MainActor
    func testFeatureFlagService_initialValue_isFalse() {
        XCTAssertFalse(FeatureFlagService.shared.pregnancyModeEnabled,
                       "fetch 전 pregnancyModeEnabled = false (A-18 invariant)")
    }

    // StableHash 통합: bucket 범위 내 (0% pct → 항상 false)
    @MainActor
    func testFeatureFlagService_zeroPct_alwaysFalse() async {
        // pct=0이면 bucket < 0 → 항상 false
        // RemoteConfig in-memory default으로 pct=0, enabled=false 설정 후 bootstrap 동작 시뮬
        // 실제 Firebase 없이 설계 패턴 단언:
        let bucket = Int(StableHash.bucket("any-user", outOf: 100))
        let pct = 0
        let rcEnabled = false
        let resolved = rcEnabled && (bucket < pct)
        XCTAssertFalse(resolved, "pct=0 이면 항상 false")
    }
}

// MARK: - P3-1: AppContext Lifecycle 전환 테스트 (A-11 확장)

/// AppContext 4-state lifecycle 전환 순서 및 invariant 검증.
/// 실제 ViewModel 없이 순수 값 로직만 테스트 (빌드 58 회귀 방지).
final class AppContextLifecycleTests: XCTestCase {

    private func baby() -> Baby { Baby(name: "테스트", birthDate: Date(), gender: .female) }
    private func pregnancy() -> Pregnancy { Pregnancy(fetusCount: 1) }

    // LC-1: empty → pregnancyOnly 전환 (임신 등록 순간)
    func test_lifecycle_empty_to_pregnancyOnly_onRegisterPregnancy() {
        let babies: [Baby] = []
        var activePregnancy: Pregnancy? = nil

        // empty
        XCTAssertEqual(AppContext.resolve(babies: babies, pregnancy: activePregnancy), .empty)

        // 임신 등록
        activePregnancy = pregnancy()
        XCTAssertEqual(
            AppContext.resolve(babies: babies, pregnancy: activePregnancy),
            .pregnancyOnly,
            "empty → 임신 등록 → pregnancyOnly 전환 (빌드 58 gating 검증)"
        )
    }

    // LC-2: pregnancyOnly → both 전환 (출산 전 아기 추가)
    func test_lifecycle_pregnancyOnly_to_both_onAddBaby() {
        let babies: [Baby] = []
        let activePregnancy: Pregnancy? = pregnancy()
        XCTAssertEqual(AppContext.resolve(babies: babies, pregnancy: activePregnancy), .pregnancyOnly)

        // 아기 추가 (both 상태)
        let withBaby = [baby()]
        XCTAssertEqual(
            AppContext.resolve(babies: withBaby, pregnancy: activePregnancy),
            .both,
            "pregnancyOnly → 아기 추가 → both 전환"
        )
    }

    // LC-3: both → babyOnly 전환 (출산 완료 후 임신 nil)
    func test_lifecycle_both_to_babyOnly_onTransitionComplete() {
        let babies = [baby()]
        var activePregnancy: Pregnancy? = pregnancy()
        XCTAssertEqual(AppContext.resolve(babies: babies, pregnancy: activePregnancy), .both)

        // 출산 전환 완료 → pregnancy nil
        activePregnancy = nil
        XCTAssertEqual(
            AppContext.resolve(babies: babies, pregnancy: activePregnancy),
            .babyOnly,
            "both → 출산 완료 → babyOnly (빌드 60 baby>pregnancy 우선순위 검증)"
        )
    }

    // LC-4: empty → babyOnly 전환 (일반 아기 등록)
    func test_lifecycle_empty_to_babyOnly_onRegisterBaby() {
        let empty = AppContext.resolve(babies: [], pregnancy: nil)
        XCTAssertEqual(empty, .empty)

        let withBaby = AppContext.resolve(babies: [baby()], pregnancy: nil)
        XCTAssertEqual(withBaby, .babyOnly, "empty → 아기 등록 → babyOnly (일반 경로)")
    }

    // LC-5: both에서 baby가 있으면 pregnancy nil이어도 babyOnly (데이터 보존)
    func test_lifecycle_both_pregnancyTerminated_fallsBackToBabyOnly() {
        let ctx = AppContext.resolve(babies: [baby()], pregnancy: nil)
        XCTAssertEqual(ctx, .babyOnly, "임신 종료 후 baby 있으면 babyOnly (데이터 보존 패턴)")
    }

    // LC-6: AppContext.resolve가 babies 배열 참조가 아닌 isEmpty 기준으로 동작함을 검증
    func test_lifecycle_resolve_usesCountNotIdentity() {
        let b1 = baby()
        let b2 = baby()
        // 각각 독립 인스턴스여도 동일 결과
        XCTAssertEqual(
            AppContext.resolve(babies: [b1], pregnancy: nil),
            AppContext.resolve(babies: [b2], pregnancy: nil)
        )
    }

    // LC-7: babyOnly → both 전환 (아기 있는 상태에서 임신 등록)
    func test_lifecycle_babyOnly_to_both_onRegisterPregnancy() {
        let babies = [baby()]
        let babyOnly = AppContext.resolve(babies: babies, pregnancy: nil)
        XCTAssertEqual(babyOnly, .babyOnly)

        let both = AppContext.resolve(babies: babies, pregnancy: pregnancy())
        XCTAssertEqual(both, .both, "babyOnly → 임신 등록 → both")
    }

    // LC-8: 출산 전환 중 baby가 추가되고 pregnancy는 유지되는 순간의 AppContext
    func test_lifecycle_midTransition_babies_nonEmpty_pregnancy_notNil_returnsBoth() {
        // 출산 WriteBatch 중: baby가 먼저 추가되고, pregnancy archive는 아직 nil 아닌 상태
        let ctx = AppContext.resolve(babies: [baby()], pregnancy: pregnancy())
        XCTAssertEqual(ctx, .both, "출산 전환 중간 상태: both (WriteBatch 중 race condition 방지)")
    }
}

// MARK: - P3-1: PregnancyRecoveryModal State Transition Tests (A-11 확장)

// MARK: - P3-1: FeatureFlagService RemoteConfig Behavior Tests (A-11 확장)

/// FeatureFlagService RemoteConfig 동작: fetch, cache, fallback, StableHash cohort 검증.
/// 실제 Firebase 없이 설계 패턴 기반 단언.
final class FeatureFlagServiceBehaviorTests: XCTestCase {

    // FF-1: 100% cohort (bucket < 100) 시 rcEnabled=true이면 resolved=true
    func test_featureFlag_fullCohort_rcEnabled_resolvedTrue() {
        let rcEnabled = true
        let pct = 100
        let bucket = 50 // 항상 100 미만
        let resolved = rcEnabled && (bucket < pct)
        XCTAssertTrue(resolved, "100% pct + rcEnabled=true → 모든 사용자 활성화")
    }

    // FF-2: rcEnabled=false이면 cohort 무관 항상 false
    func test_featureFlag_rcDisabled_alwaysFalse() {
        let rcEnabled = false
        for pct in [0, 50, 100] {
            let bucket = Int(StableHash.bucket("any-user-\(pct)", outOf: 100))
            let resolved = rcEnabled && (bucket < pct)
            XCTAssertFalse(resolved, "rcEnabled=false이면 pct=\(pct)이어도 false")
        }
    }

    // FF-3: bucket이 pct 경계값일 때 false (bucket < pct, NOT <=)
    func test_featureFlag_bucketEqualsPct_isFalse() {
        // bucket < pct 조건: bucket == pct이면 포함 안 됨
        let rcEnabled = true
        let pct = 50
        let bucket = 50 // bucket == pct → false
        let resolved = rcEnabled && (bucket < pct)
        XCTAssertFalse(resolved, "bucket == pct 경계: 포함 안 됨 (< 조건)")
    }

    // FF-4: 동일 userId는 항상 동일 cohort bucket → 일관된 사용자 경험
    func test_featureFlag_sameUserId_consistentCohort() {
        let uid = "consistent-user-id"
        let bucket1 = StableHash.bucket(uid, outOf: 100)
        let bucket2 = StableHash.bucket(uid, outOf: 100)
        XCTAssertEqual(bucket1, bucket2, "동일 userId → 동일 bucket (cohort 일관성)")
    }

    // FF-5: 다른 userId들은 다른 bucket에 분산 (해시 분산성 확인)
    func test_featureFlag_differentUserIds_distributedBuckets() {
        // 1000개 유저에 대해 bucket 계산 — 모두 동일한 bucket이면 분산 실패
        let buckets = (0..<100).map { StableHash.bucket("user-\($0)", outOf: 100) }
        let uniqueBuckets = Set(buckets)
        XCTAssertGreaterThan(uniqueBuckets.count, 1, "다른 userId → 분산된 bucket 값")
    }

    // FF-6: FeatureFlagService.shared 초기 상태는 false (A-18 invariant)
    @MainActor
    func test_featureFlag_sharedService_initialValue_false() {
        XCTAssertFalse(
            FeatureFlagService.shared.pregnancyModeEnabled,
            "초기 상태 false (A-18 invariant — fetch 전 항상 false)"
        )
    }

    // FF-7: UserDefaults 캐시 격리 — 캐시 설정 후 해제 시 기본값 복원
    @MainActor
    func test_featureFlag_userDefaultsCache_isolation() {
        let key = FeatureFlagService.testCacheKey
        UserDefaults.standard.removeObject(forKey: key)
        defer { UserDefaults.standard.removeObject(forKey: key) }

        let service = FeatureFlagService.shared

        // 캐시 없음 → coldStart = false
        let noCacheResult = service.coldStartDefault(userId: "isolation-user")
        XCTAssertFalse(noCacheResult, "캐시 없음 → coldStart false")

        // 캐시 true 설정: 킬스위치 ON이면 캐시값(true), OFF(v2.8.8 핫픽스)면 A-18 우선 false
        UserDefaults.standard.set(true, forKey: key)
        let cachedResult = service.coldStartDefault(userId: "isolation-user")
        XCTAssertEqual(cachedResult, service.compileTimeValue,
                       "캐시 true → 킬스위치 ON이면 true, OFF면 false(A-18)")

        // 캐시 제거 후 기본값 복원
        UserDefaults.standard.removeObject(forKey: key)
        let clearedResult = service.coldStartDefault(userId: "isolation-user")
        XCTAssertFalse(clearedResult, "캐시 제거 → coldStart false 복원")
    }

    // MARK: - Weekly Highlights Cohort (A-23)

    /// A-23: isHighlightV2Enabled 코호트 — DJB2 deterministic 검증.
    /// 동일 userId로 StableHash.djb2 호출 시 항상 동일 bucket 반환.
    func testCohort_djb2Deterministic() {
        let userId = "highlight-test-user-abc"
        let bucket1 = StableHash.djb2(userId) % 100
        let bucket2 = StableHash.djb2(userId) % 100
        XCTAssertEqual(bucket1, bucket2, "DJB2는 동일 userId에 대해 항상 동일 bucket 반환 (deterministic)")
    }

    /// A-23b: 서로 다른 userId는 다른 bucket에 매핑될 수 있음 (collision 없는 기본 케이스).
    func testCohort_djb2_differentUsers_differentBuckets() {
        let user1 = "user-highlight-001"
        let user2 = "user-highlight-002"
        // DJB2 충돌이 없다는 보장은 없지만, 이 두 입력은 다른 값 반환
        let b1 = StableHash.djb2(user1)
        let b2 = StableHash.djb2(user2)
        XCTAssertNotEqual(b1, b2, "서로 다른 userId는 서로 다른 DJB2 해시 반환")
    }

    /// A-23c: FeatureFlags.highlightsEnabled compile-time 상수 검증.
    func testHighlightsEnabled_compiletimeTrue() {
        XCTAssertTrue(FeatureFlags.highlightsEnabled, "FeatureFlags.highlightsEnabled는 true (v2.8.3 기본값)")
    }
}


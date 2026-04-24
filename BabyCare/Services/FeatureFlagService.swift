import Foundation
import FirebaseRemoteConfig

// MARK: - FeatureFlagService
// Hybrid 3-layer 게이팅:
//   Layer 1: compile-time kill switch (FeatureFlags.pregnancyModeEnabled)
//   Layer 2: Firebase RemoteConfig + 코호트 rollout % (StableHash)
//   Layer 3: UserDefaults cold-start cache (오프라인 fallback)
//
// A-18 Invariant: fetch 실패 시 fallback = false (NEVER true).
// NOTE: project.yml Firebase SDK = "11.0.0". fetchAndActivate async API는
//       Firebase iOS SDK 9.0+부터 지원. 11.0.0에서 정상 동작.
//       Firebase 11.8+ async/throws 서명 차이 없음 (P0-2b 머지 후에도 호환).

@MainActor
@Observable
final class FeatureFlagService {

    // MARK: - Singleton

    static let shared = FeatureFlagService()

    // MARK: - Public State

    /// 임신 모드 활성화 여부. 기본값 false (A-18 invariant).
    private(set) var pregnancyModeEnabled: Bool = false

    // MARK: - Private

    /// Layer 1: compile-time kill switch
    private let compileTime = FeatureFlags.pregnancyModeEnabled

    /// UserDefaults 캐시 키 (Layer 3)
    private static let cacheKey = "lastKnownGood_pregnancyModeEnabled"

    /// RemoteConfig key 상수
    private enum RCKey {
        static let enabled = "pregnancy_mode_enabled"
        static let rolloutPct = "pregnancy_rollout_pct"
    }

    // MARK: - Init (private for singleton enforcement)

    private init() {}

    // MARK: - Bootstrap

    /// App 시작 시 호출. ContentView.task 외부 (BabyCareApp.init 직후 .task)에서 실행.
    /// - Parameter userId: Firebase Auth currentUserId (코호트 버킷 결정에 사용)
    func bootstrap(userId: String) async {
        // Layer 1: compile-time kill switch
        guard compileTime else {
            pregnancyModeEnabled = false
            return
        }

        // RemoteConfig defaults 설정 (fetch 실패 시 in-memory default 적용)
        RemoteConfig.remoteConfig().setDefaults([
            RCKey.enabled: false as NSObject,
            RCKey.rolloutPct: 0 as NSObject
        ])

        // Layer 2: RemoteConfig fetch & cohort bucketing
        // fetchAndActivate 실패 시 try? 로 무시 → defaults(false) 유지 (A-18)
        _ = try? await RemoteConfig.remoteConfig().fetchAndActivate()

        let rcEnabled = RemoteConfig.remoteConfig()
            .configValue(forKey: RCKey.enabled).boolValue
        let rcPct = RemoteConfig.remoteConfig()
            .configValue(forKey: RCKey.rolloutPct).numberValue.intValue
        let bucket = Int(StableHash.bucket(userId))

        // AND-combine 금지 (Codex Rec-3): compile-time은 이미 Layer 1에서 guard 통과.
        // Layer 2 단독 평가 (fetch 실패 시 rcEnabled=false → false 보장).
        let resolved = rcEnabled && (bucket < rcPct)

        pregnancyModeEnabled = resolved

        // Layer 3: 성공 시 캐시 갱신
        UserDefaults.standard.set(resolved, forKey: FeatureFlagService.cacheKey)
    }

    // MARK: - Cold Start (Layer 3)

    /// RemoteConfig fetch 전 cold start 값. 오프라인 시 마지막 성공 상태 복원.
    /// compile-time=false이면 항상 false 반환 (A-18).
    func coldStartDefault(userId: String) -> Bool {
        guard compileTime else { return false }
        return UserDefaults.standard.object(forKey: FeatureFlagService.cacheKey) as? Bool ?? false
    }

    // MARK: - Test Support

    /// 테스트 전용: UserDefaults 캐시 키 노출
    static var testCacheKey: String { cacheKey }

    /// 테스트 전용: compile-time kill switch 값 반환
    var compileTimeValue: Bool { compileTime }
}

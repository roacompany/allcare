import Foundation
import HealthKit
import SwiftUI

/// HealthKit 임신 데이터 연동 서비스.
/// opt-in 기본 off, 설정 탭 토글로 활성화.
/// ⚠️ HealthKit 데이터를 광고/Analytics로 전송 금지 (App Store Review 5.1.1).
@MainActor
final class HealthKitPregnancyService {
    static let shared = HealthKitPregnancyService()

    private let healthStore = HKHealthStore()
    private let isAvailable = HKHealthStore.isHealthDataAvailable()

    /// 사용자 opt-in 상태.
    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "pregnancyHealthKitEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "pregnancyHealthKitEnabled") }
    }

    // MARK: - Authorization

    /// 권한 요청. 거부 시 graceful fallback (앱 기능 영향 없음).
    func requestAuthorization() async throws {
        guard isAvailable else { return }

        let readTypes: Set<HKObjectType> = [
            HKCategoryType(.pregnancy)
        ]
        let writeTypes: Set<HKSampleType> = [
            HKCategoryType(.pregnancy)
        ]

        try await healthStore.requestAuthorization(toShare: writeTypes, read: readTypes)
    }

    // MARK: - Sync

    /// Pregnancy 생성/업데이트 시 HealthKit에 동기화.
    func syncPregnancy(dueDate: Date) async {
        guard isAvailable, isEnabled else { return }

        // 기존 임신 데이터 삭제 후 재등록 (중복 방지).
        let pregnancyType = HKCategoryType(.pregnancy)
        let predicate = HKQuery.predicateForSamples(withStart: nil, end: nil)
        if let existing = try? await withCheckedThrowingContinuation({ (cont: CheckedContinuation<[HKSample], Error>) in
            let query = HKSampleQuery(sampleType: pregnancyType, predicate: predicate, limit: 10, sortDescriptors: nil) { _, results, error in
                if let error { cont.resume(throwing: error) } else { cont.resume(returning: results ?? []) }
            }
            healthStore.execute(query)
        }) {
            for sample in existing {
                try? await healthStore.delete(sample)
            }
        }

        // 새 임신 샘플 저장. LMP ~ dueDate 범위.
        let lmpDate = Calendar.current.date(byAdding: .day, value: -280, to: dueDate) ?? Date()
        let sample = HKCategorySample(
            type: pregnancyType,
            value: HKCategoryValue.notApplicable.rawValue,
            start: lmpDate,
            end: dueDate
        )
        try? await healthStore.save(sample)
    }

    /// 권한 거부 시 graceful — 에러만 로깅, 앱 기능 차단 없음.
    func checkAuthorizationStatus() -> HKAuthorizationStatus {
        guard isAvailable else { return .notDetermined }
        return healthStore.authorizationStatus(for: HKCategoryType(.pregnancy))
    }
}

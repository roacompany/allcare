import Foundation

@MainActor @Observable
final class GrowthViewModel {
    var records: [GrowthRecord] = []
    var isLoading = false
    var saveError: String?

    private let firestoreService = FirestoreService.shared

    // MARK: - Load

    func loadRecords(userId: String, babyId: String) async {
        isLoading = true
        defer { isLoading = false }
        records = (try? await firestoreService.fetchGrowthRecords(userId: userId, babyId: babyId)) ?? []
    }

    // MARK: - Save

    /// 성장 기록 저장.
    /// - Parameter userId: 데이터 저장 path (가족 공유 시 owner uid).
    /// - Parameter currentUserId: 배지 부여 본인 uid (H-4 회귀 fix).
    func saveRecord(_ record: GrowthRecord, userId: String, currentUserId: String, baby: Baby? = nil) async throws {
        try await firestoreService.saveGrowthRecord(record, userId: userId)
        AnalyticsService.shared.trackEvent(AnalyticsEvents.growthDataInput)
        records.append(record)
        records.sort { $0.date < $1.date }
        let event = BadgeEvaluator.Event(kind: .growthLogged, babyId: record.babyId, at: record.date)
        let earned = await BadgeEvaluator().evaluate(event: event, userId: currentUserId)
        AppState.shared.badgePresenter.enqueue(earned)

        // 위젯 성장 백분위 동기화
        if let baby {
            syncWidgetGrowthPercentile(record: record, baby: baby)
        }
    }

    // MARK: - Widget Sync

    private func syncWidgetGrowthPercentile(record: GrowthRecord, baby: Baby) {
        let calendar = Calendar.current
        let ageMonths = calendar.dateComponents([.month], from: baby.birthDate, to: record.date).month ?? 0

        let weightPct: Double?
        if let weight = record.weight {
            weightPct = PercentileCalculator.percentile(value: weight, ageMonths: ageMonths, gender: baby.gender, metric: .weight)
        } else {
            weightPct = nil
        }

        let heightPct: Double?
        if let height = record.height {
            heightPct = PercentileCalculator.percentile(value: height, ageMonths: ageMonths, gender: baby.gender, metric: .height)
        } else {
            heightPct = nil
        }

        let percentile = WidgetGrowthPercentile(
            weightKg: record.weight,
            weightPercentile: weightPct,
            heightCm: record.height,
            heightPercentile: heightPct,
            measuredAt: record.date
        )
        WidgetDataStore.updateGrowthPercentile(percentile)
    }

    // MARK: - Update

    func updateRecord(_ updated: GrowthRecord, userId: String) async throws {
        try await firestoreService.updateGrowthRecord(updated, userId: userId)
        if let idx = records.firstIndex(where: { $0.id == updated.id }) {
            records[idx] = updated
            records.sort { $0.date < $1.date }
        }
    }

    // MARK: - Delete

    func deleteRecord(_ record: GrowthRecord, userId: String, babyId: String) async throws {
        try await firestoreService.deleteGrowthRecord(record.id, userId: userId, babyId: babyId)
        records.removeAll { $0.id == record.id }
    }

    // MARK: - Growth Velocity Alert

    func scheduleGrowthVelocityAlert(baby: Baby) {
        let babyName = baby.name
        for metric in [GrowthMetric.weight, .height, .headCircumference] {
            if let result = PercentileCalculator.growthVelocity(
                records: records,
                metric: metric,
                gender: baby.gender,
                birthDate: baby.birthDate
            ), result.isSignificant {
                Task { @MainActor in
                    NotificationService.shared.scheduleGrowthVelocityAlert(babyName: babyName)
                }
                break
            }
        }
    }
}

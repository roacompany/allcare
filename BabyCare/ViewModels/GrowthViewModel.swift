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

    func saveRecord(_ record: GrowthRecord, userId: String) async throws {
        try await firestoreService.saveGrowthRecord(record, userId: userId)
        AnalyticsService.shared.trackEvent(AnalyticsEvents.growthDataInput)
        records.append(record)
        records.sort { $0.date < $1.date }
        let event = BadgeEvaluator.Event(kind: .growthLogged, babyId: record.babyId, at: record.date)
        let earned = await BadgeEvaluator().evaluate(event: event, userId: userId)
        AppState.shared.badgePresenter.enqueue(earned)
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

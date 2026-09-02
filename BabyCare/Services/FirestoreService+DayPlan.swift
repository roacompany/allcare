import Foundation
import FirebaseFirestore

/// 시간표 저장소 — VM 이 의존하는 좁은 면.
protocol DayPlanFirestoreProviding: Sendable {
    func fetchDayPlans(userId: String) async throws -> [DayPlan]
    func saveDayPlan(_ plan: DayPlan, userId: String) async throws
    func deleteDayPlan(_ planId: String, userId: String) async throws
}

extension FirestoreService {

    private func dayPlanCollection(_ userId: String) -> CollectionReference {
        db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.dayPlans)
    }

    func fetchDayPlans(userId: String) async throws -> [DayPlan] {
        let snapshot = try await dayPlanCollection(userId)
            .order(by: "createdAt", descending: false)
            .getDocuments()
        return decodeDocuments(snapshot.documents, as: DayPlan.self)
    }

    func saveDayPlan(_ plan: DayPlan, userId: String) async throws {
        try dayPlanCollection(userId).document(plan.id).setData(from: plan)
    }

    func deleteDayPlan(_ planId: String, userId: String) async throws {
        try await dayPlanCollection(userId).document(planId).delete()
    }
}

extension FirestoreService: DayPlanFirestoreProviding {}

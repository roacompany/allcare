import FirebaseFirestore
import Foundation

extension FirestoreService {
        // MARK: - Activity

    func saveActivity(_ activity: Activity, userId: String) async throws {
        let ref = db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.babies)
            .document(activity.babyId)
            .collection(FirestoreCollections.activities)
            .document(activity.id)
        try ref.setData(from: activity)
    }

    func fetchActivities(userId: String, babyId: String, date: Date) async throws -> [Activity] {
        let start = date.startOfDay
        let end = date.endOfDay
        let snapshot = try await db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.babies)
            .document(babyId)
            .collection(FirestoreCollections.activities)
            .whereField("startTime", isGreaterThanOrEqualTo: Timestamp(date: start))
            .whereField("startTime", isLessThanOrEqualTo: Timestamp(date: end))
            .order(by: "startTime", descending: true)
            .getDocuments()
        return decodeDocuments(snapshot.documents, as: Activity.self)
    }

    func fetchActivities(userId: String, babyId: String, from startDate: Date, to endDate: Date) async throws -> [Activity] {
        let snapshot = try await db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.babies)
            .document(babyId)
            .collection(FirestoreCollections.activities)
            .whereField("startTime", isGreaterThanOrEqualTo: Timestamp(date: startDate))
            .whereField("startTime", isLessThanOrEqualTo: Timestamp(date: endDate))
            .order(by: "startTime", descending: true)
            .getDocuments()
        return decodeDocuments(snapshot.documents, as: Activity.self)
    }

    /// 백필용 count 집계 — 주어진 ActivityType rawValues를 포함하는 문서 수를 서버에서 집계.
    func countActivities(userId: String, babyId: String, typeRawValues: [String]) async throws -> Int {
        guard !typeRawValues.isEmpty else { return 0 }
        let query = db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.babies)
            .document(babyId)
            .collection(FirestoreCollections.activities)
            .whereField("type", in: typeRawValues)
        let agg = try await query.count.getAggregation(source: .server)
        return agg.count.intValue
    }

    /// 백필용 earliest — 가장 오래된 activity의 startTime 반환.
    func fetchEarliestActivity(userId: String, babyId: String) async throws -> Activity? {
        let snapshot = try await db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.babies)
            .document(babyId)
            .collection(FirestoreCollections.activities)
            .order(by: "startTime", descending: false)
            .limit(to: 1)
            .getDocuments()
        return decodeDocuments(snapshot.documents, as: Activity.self).first
    }

    func fetchLatestActivity(userId: String, babyId: String, type: Activity.ActivityType) async throws -> Activity? {
        let snapshot = try await db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.babies)
            .document(babyId)
            .collection(FirestoreCollections.activities)
            .whereField("type", isEqualTo: type.rawValue)
            .order(by: "startTime", descending: true)
            .limit(to: 1)
            .getDocuments()
        return decodeDocuments(snapshot.documents, as: Activity.self).first
    }

    func deleteActivity(_ activityId: String, userId: String, babyId: String) async throws {
        try await db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.babies)
            .document(babyId)
            .collection(FirestoreCollections.activities)
            .document(activityId)
            .delete()
    }
}

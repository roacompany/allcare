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

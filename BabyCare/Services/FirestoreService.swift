import Foundation
import FirebaseFirestore

final class FirestoreService: Sendable {
    static let shared = FirestoreService()
    private let db = Firestore.firestore()

    private init() {}

    // MARK: - Baby

    func saveBaby(_ baby: Baby, userId: String) async throws {
        let ref = db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.babies)
            .document(baby.id)
        try ref.setData(from: baby)
    }

    func fetchBabies(userId: String) async throws -> [Baby] {
        let snapshot = try await db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.babies)
            .order(by: "createdAt", descending: false)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: Baby.self) }
    }

    func deleteBaby(_ babyId: String, userId: String) async throws {
        try await db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.babies)
            .document(babyId)
            .delete()
    }

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
        return snapshot.documents.compactMap { try? $0.data(as: Activity.self) }
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
        return snapshot.documents.compactMap { try? $0.data(as: Activity.self) }
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
        return snapshot.documents.first.flatMap { try? $0.data(as: Activity.self) }
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

    // MARK: - Growth

    func saveGrowthRecord(_ record: GrowthRecord, userId: String) async throws {
        let ref = db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.babies)
            .document(record.babyId)
            .collection(FirestoreCollections.growth)
            .document(record.id)
        try ref.setData(from: record)
    }

    func fetchGrowthRecords(userId: String, babyId: String) async throws -> [GrowthRecord] {
        let snapshot = try await db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.babies)
            .document(babyId)
            .collection(FirestoreCollections.growth)
            .order(by: "date", descending: false)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: GrowthRecord.self) }
    }

    // MARK: - Diary

    func saveDiaryEntry(_ entry: DiaryEntry, userId: String) async throws {
        let ref = db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.babies)
            .document(entry.babyId)
            .collection(FirestoreCollections.diary)
            .document(entry.id)
        try ref.setData(from: entry)
    }

    func fetchDiaryEntries(userId: String, babyId: String) async throws -> [DiaryEntry] {
        let snapshot = try await db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.babies)
            .document(babyId)
            .collection(FirestoreCollections.diary)
            .order(by: "date", descending: true)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: DiaryEntry.self) }
    }

    // MARK: - Todo

    func saveTodo(_ todo: TodoItem, userId: String) async throws {
        let ref = db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.todos)
            .document(todo.id)
        try ref.setData(from: todo)
    }

    func fetchTodos(userId: String) async throws -> [TodoItem] {
        let snapshot = try await db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.todos)
            .order(by: "createdAt", descending: true)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: TodoItem.self) }
    }

    func deleteTodo(_ todoId: String, userId: String) async throws {
        try await db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.todos)
            .document(todoId)
            .delete()
    }

    // MARK: - Routine

    func saveRoutine(_ routine: Routine, userId: String) async throws {
        let ref = db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.routines)
            .document(routine.id)
        try ref.setData(from: routine)
    }

    func fetchRoutines(userId: String) async throws -> [Routine] {
        let snapshot = try await db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.routines)
            .order(by: "createdAt", descending: false)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: Routine.self) }
    }

    func deleteRoutine(_ routineId: String, userId: String) async throws {
        try await db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.routines)
            .document(routineId)
            .delete()
    }
}

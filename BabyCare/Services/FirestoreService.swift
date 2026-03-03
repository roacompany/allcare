import Foundation
import FirebaseFirestore
import OSLog

final class FirestoreService: Sendable {
    static let shared = FirestoreService()
    nonisolated(unsafe) private let db = Firestore.firestore()
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "BabyCare", category: "Firestore")

    private init() {}

    /// Firestore 문서 배열 디코딩. 개별 실패는 로깅 후 스킵.
    private func decodeDocuments<T: Decodable>(_ documents: [QueryDocumentSnapshot], as type: T.Type) -> [T] {
        documents.compactMap { doc in
            do {
                return try doc.data(as: T.self)
            } catch {
                Self.logger.warning("Document \(doc.documentID) decode failed: \(error.localizedDescription)")
                return nil
            }
        }
    }

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
        return decodeDocuments(snapshot.documents, as: Baby.self)
    }

    /// Baby 삭제 시 하위 컬렉션(activities, growth, diary)도 함께 삭제.
    func deleteBaby(_ babyId: String, userId: String) async throws {
        let babyRef = db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.babies)
            .document(babyId)

        // 하위 컬렉션 cascade 삭제
        for subcollection in [FirestoreCollections.activities, FirestoreCollections.growth, FirestoreCollections.diary] {
            let docs = try await babyRef.collection(subcollection).getDocuments()
            for doc in docs.documents {
                try await doc.reference.delete()
            }
        }

        try await babyRef.delete()
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
        return decodeDocuments(snapshot.documents, as: GrowthRecord.self)
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
        return decodeDocuments(snapshot.documents, as: DiaryEntry.self)
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
        return decodeDocuments(snapshot.documents, as: TodoItem.self)
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
        return decodeDocuments(snapshot.documents, as: Routine.self)
    }

    func deleteRoutine(_ routineId: String, userId: String) async throws {
        try await db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.routines)
            .document(routineId)
            .delete()
    }

    // MARK: - Product

    func saveProduct(_ product: BabyProduct, userId: String) async throws {
        let ref = db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.products)
            .document(product.id)
        try ref.setData(from: product)
    }

    func fetchProducts(userId: String) async throws -> [BabyProduct] {
        let snapshot = try await db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.products)
            .order(by: "updatedAt", descending: true)
            .getDocuments()
        return decodeDocuments(snapshot.documents, as: BabyProduct.self)
    }

    func deleteProduct(_ productId: String, userId: String) async throws {
        try await db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.products)
            .document(productId)
            .delete()
    }

    // MARK: - Vaccination

    func saveVaccination(_ vaccination: Vaccination, userId: String) async throws {
        let ref = db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.babies)
            .document(vaccination.babyId)
            .collection(FirestoreCollections.vaccinations)
            .document(vaccination.id)
        try ref.setData(from: vaccination)
    }

    func saveVaccinations(_ vaccinations: [Vaccination], userId: String) async throws {
        let batch = db.batch()
        for vax in vaccinations {
            let ref = db.collection(FirestoreCollections.users)
                .document(userId)
                .collection(FirestoreCollections.babies)
                .document(vax.babyId)
                .collection(FirestoreCollections.vaccinations)
                .document(vax.id)
            try batch.setData(from: vax, forDocument: ref)
        }
        try await batch.commit()
    }

    func fetchVaccinations(userId: String, babyId: String) async throws -> [Vaccination] {
        let snapshot = try await db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.babies)
            .document(babyId)
            .collection(FirestoreCollections.vaccinations)
            .order(by: "scheduledDate", descending: false)
            .getDocuments()
        return decodeDocuments(snapshot.documents, as: Vaccination.self)
    }

    // MARK: - Milestone

    func saveMilestone(_ milestone: Milestone, userId: String) async throws {
        let ref = db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.babies)
            .document(milestone.babyId)
            .collection(FirestoreCollections.milestones)
            .document(milestone.id)
        try ref.setData(from: milestone)
    }

    func saveMilestones(_ milestones: [Milestone], userId: String) async throws {
        let batch = db.batch()
        for ms in milestones {
            let ref = db.collection(FirestoreCollections.users)
                .document(userId)
                .collection(FirestoreCollections.babies)
                .document(ms.babyId)
                .collection(FirestoreCollections.milestones)
                .document(ms.id)
            try batch.setData(from: ms, forDocument: ref)
        }
        try await batch.commit()
    }

    func fetchMilestones(userId: String, babyId: String) async throws -> [Milestone] {
        let snapshot = try await db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.babies)
            .document(babyId)
            .collection(FirestoreCollections.milestones)
            .order(by: "expectedAgeMonths", descending: false)
            .getDocuments()
        return decodeDocuments(snapshot.documents, as: Milestone.self)
    }

    // MARK: - Hospital Visit

    func saveHospitalVisit(_ visit: HospitalVisit, userId: String) async throws {
        let ref = db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.babies)
            .document(visit.babyId)
            .collection(FirestoreCollections.hospitalVisits)
            .document(visit.id)
        try ref.setData(from: visit)
    }

    func fetchHospitalVisits(userId: String, babyId: String) async throws -> [HospitalVisit] {
        let snapshot = try await db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.babies)
            .document(babyId)
            .collection(FirestoreCollections.hospitalVisits)
            .order(by: "visitDate", descending: true)
            .getDocuments()
        return decodeDocuments(snapshot.documents, as: HospitalVisit.self)
    }

    func deleteHospitalVisit(_ visitId: String, userId: String, babyId: String) async throws {
        try await db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.babies)
            .document(babyId)
            .collection(FirestoreCollections.hospitalVisits)
            .document(visitId)
            .delete()
    }

    // MARK: - Family Invite

    func saveInvite(_ invite: FamilyInvite) async throws {
        let ref = db.collection(FirestoreCollections.invites).document(invite.id)
        try ref.setData(from: invite)
    }

    func findInviteByCode(_ code: String) async throws -> FamilyInvite? {
        let snapshot = try await db.collection(FirestoreCollections.invites)
            .whereField("code", isEqualTo: code)
            .whereField("isUsed", isEqualTo: false)
            .limit(to: 1)
            .getDocuments()
        return decodeDocuments(snapshot.documents, as: FamilyInvite.self).first
    }

    func markInviteUsed(_ inviteId: String) async throws {
        try await db.collection(FirestoreCollections.invites)
            .document(inviteId)
            .updateData(["isUsed": true])
    }

    // MARK: - Shared Access

    func saveSharedAccess(_ access: SharedBabyAccess, userId: String) async throws {
        let ref = db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.sharedAccess)
            .document(access.id)
        try ref.setData(from: access)
    }

    func fetchSharedAccess(userId: String) async throws -> [SharedBabyAccess] {
        let snapshot = try await db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.sharedAccess)
            .getDocuments()
        return decodeDocuments(snapshot.documents, as: SharedBabyAccess.self)
    }

    // MARK: - Announcements

    func fetchActiveAnnouncements() async throws -> [Announcement] {
        let snapshot = try await db.collection(FirestoreCollections.announcements)
            .whereField("isActive", isEqualTo: true)
            .order(by: "createdAt", descending: true)
            .limit(to: 20)
            .getDocuments()
        return decodeDocuments(snapshot.documents, as: Announcement.self)
    }

    // MARK: - Admin: Announcements

    func fetchAllAnnouncements() async throws -> [Announcement] {
        let snapshot = try await db.collection(FirestoreCollections.announcements)
            .order(by: "createdAt", descending: true)
            .getDocuments()
        return decodeDocuments(snapshot.documents, as: Announcement.self)
    }

    func saveAnnouncement(_ announcement: Announcement) async throws {
        if let id = announcement.id {
            let ref = db.collection(FirestoreCollections.announcements).document(id)
            try ref.setData(from: announcement)
        } else {
            let ref = db.collection(FirestoreCollections.announcements).document()
            try ref.setData(from: announcement)
        }
    }

    func deleteAnnouncement(_ id: String) async throws {
        try await db.collection(FirestoreCollections.announcements)
            .document(id)
            .delete()
    }

    // MARK: - Admin: User Count

    func fetchUserCount() async throws -> Int {
        let snapshot = try await db.collection(FirestoreCollections.users)
            .getDocuments()
        return snapshot.count
    }

    // MARK: - Purchase Records

    func savePurchaseRecord(_ record: PurchaseRecord, userId: String) async throws {
        let ref = db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.purchases)
            .document(record.id)
        try ref.setData(from: record)
    }

    func fetchPurchaseRecords(userId: String) async throws -> [PurchaseRecord] {
        let snapshot = try await db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.purchases)
            .order(by: "purchaseDate", descending: true)
            .getDocuments()
        return decodeDocuments(snapshot.documents, as: PurchaseRecord.self)
    }

    func fetchPurchaseRecords(userId: String, from startDate: Date, to endDate: Date) async throws -> [PurchaseRecord] {
        let snapshot = try await db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.purchases)
            .whereField("purchaseDate", isGreaterThanOrEqualTo: Timestamp(date: startDate))
            .whereField("purchaseDate", isLessThanOrEqualTo: Timestamp(date: endDate))
            .order(by: "purchaseDate", descending: true)
            .getDocuments()
        return decodeDocuments(snapshot.documents, as: PurchaseRecord.self)
    }

    func deletePurchaseRecord(_ recordId: String, userId: String) async throws {
        try await db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.purchases)
            .document(recordId)
            .delete()
    }

    // MARK: - Baby (single)

    func fetchBaby(userId: String, babyId: String) async throws -> Baby? {
        let doc = try await db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.babies)
            .document(babyId)
            .getDocument()
        do {
            return try doc.data(as: Baby.self)
        } catch {
            Self.logger.warning("Baby \(babyId) decode failed: \(error.localizedDescription)")
            return nil
        }
    }
}

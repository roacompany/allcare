import FirebaseFirestore
import Foundation

extension FirestoreService {
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

    // MARK: - Hospital Visit
}

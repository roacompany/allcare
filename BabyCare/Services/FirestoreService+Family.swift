import FirebaseFirestore
import Foundation

extension FirestoreService {
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
        let collectionRef = db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.sharedAccess)

        // Try fetching all documents; migrate legacy UUID-keyed docs on the fly
        let snapshot = try await collectionRef.getDocuments()
        var results: [SharedBabyAccess] = []

        for doc in snapshot.documents {
            guard var access = try? doc.data(as: SharedBabyAccess.self) else { continue }
            let expectedId = "\(access.ownerUserId)_\(access.babyId)"

            if doc.documentID != expectedId {
                // Legacy UUID document — re-save under new ID then delete old one
                access.id = expectedId
                let newRef = collectionRef.document(expectedId)
                try? newRef.setData(from: access)
                try? await doc.reference.delete()
            }

            results.append(access)
        }

        return results
    }

    func removeSharedAccess(accessId: String, userId: String) async throws {
        try await db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.sharedAccess)
            .document(accessId)
            .delete()
    }

    func checkDuplicateAccess(userId: String, ownerUserId: String, babyId: String) async throws -> Bool {
        let docId = "\(ownerUserId)_\(babyId)"
        let docRef = db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.sharedAccess)
            .document(docId)
        let snapshot = try await docRef.getDocument()
        return snapshot.exists
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
}

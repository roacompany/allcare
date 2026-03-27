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

        // Decode all documents and identify legacy ones (non-composite ID)
        struct DocInfo {
            let doc: QueryDocumentSnapshot
            var access: SharedBabyAccess
            let expectedId: String
            var isLegacy: Bool { doc.documentID != expectedId }
        }
        let docInfos: [DocInfo] = snapshot.documents.compactMap { doc in
            guard let access = try? doc.data(as: SharedBabyAccess.self) else { return nil }
            let expectedId = "\(access.ownerUserId)_\(access.babyId)"
            return DocInfo(doc: doc, access: access, expectedId: expectedId)
        }

        // Batch-check existence of new composite-ID documents in parallel for legacy docs
        // Use Firestore.firestore() singleton inside the closure to avoid capturing
        // non-Sendable locals (Swift 6 sending parameter requirement)
        let legacyExpectedIds = docInfos.filter { $0.isLegacy }.map { $0.expectedId }
        let collectionPath = collectionRef.path  // String — Sendable
        let existingMap: [String: Bool]
        if legacyExpectedIds.isEmpty {
            existingMap = [:]
        } else {
            existingMap = await withTaskGroup(of: (String, Bool).self) { group in
                for expectedId in legacyExpectedIds {
                    group.addTask {
                        // Obtain the Firestore singleton directly — avoids capturing a local
                        let ref = Firestore.firestore().collection(collectionPath).document(expectedId)
                        let snap = try? await ref.getDocument()
                        return (expectedId, snap?.exists ?? false)
                    }
                }
                var map: [String: Bool] = [:]
                for await (id, exists) in group { map[id] = exists }
                return map
            }
        }

        // Process migration and collect results
        var results: [SharedBabyAccess] = []
        for var info in docInfos {
            if info.isLegacy {
                let newRef = collectionRef.document(info.expectedId)
                if existingMap[info.expectedId] == true {
                    // New document already present; delete stale legacy doc and skip
                    try? await info.doc.reference.delete()
                    continue
                }
                // Write new document first; only delete old if write succeeds
                info.access.id = info.expectedId
                do {
                    try newRef.setData(from: info.access)
                    try? await info.doc.reference.delete()
                } catch {
                    // Write failed — keep legacy doc and skip adding to results
                    continue
                }
            }
            results.append(info.access)
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

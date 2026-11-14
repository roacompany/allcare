import FirebaseFirestore
import Foundation

extension FirestoreService {
        // MARK: - Family Invite

    func saveInvite(_ invite: FamilyInvite) async throws {
        // 문서 ID = 초대코드. 규칙이 코드로 단건 조회·교차검증한다(열거 차단).
        let ref = db.collection(FirestoreCollections.invites).document(invite.code)
        // await = 서버 확인까지 대기. code 충돌(남의 문서→update 규칙 거부)·규칙 거부를 삼키지 않는다.
        try await ref.setData(from: invite)
    }

    func findInviteByCode(_ code: String) async throws -> FamilyInvite? {
        // 사람이 친 글자가 그대로 문서 경로가 된다 — 「/」가 섞인 홀수 경로는 SDK 가 NSException 으로 앱을 끈다.
        // 초대 코드 모양이 아니면 조회하지 않고 「없음」으로 끝낸다(서버에도 안 닿는다).
        guard FamilyInvite.isWellFormedCode(code) else { return nil }
        // 코드 = 문서 ID 이므로 단건 조회(쿼리 아님 — invites 열거는 규칙상 차단).
        let snapshot = try await db.collection(FirestoreCollections.invites)
            .document(code)
            .getDocument()
        guard let invite = try? snapshot.data(as: FamilyInvite.self), !invite.isUsed else {
            return nil
        }
        return invite
    }

    func markInviteUsed(_ code: String) async throws {
        try await db.collection(FirestoreCollections.invites)
            .document(code)
            .updateData(["isUsed": true])
    }

    // MARK: - Shared Access

    func saveSharedAccess(_ access: SharedBabyAccess, userId: String) async throws {
        let ref = db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.sharedAccess)
            .document(access.id)
        // await = 서버 확인까지 대기. 초대코드 교차검증 규칙이 거부하면(만료·사용됨·코드 불일치)
        // joinFamily 가 성공으로 오인하지 않고 에러를 받는다.
        try await ref.setData(from: access)
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
                        do {
                            let snap = try await ref.getDocument()
                            return (expectedId, snap.exists)
                        } catch {
                            logSilent("legacy 신형 존재 확인 실패: \(expectedId)", error: error, logger: AppLogger.firestore)
                            return (expectedId, false)
                        }
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
                    do {
                        try await info.doc.reference.delete()
                    } catch {
                        logSilent("legacy 중복 doc 삭제 실패: \(info.expectedId)", error: error, logger: AppLogger.firestore)
                    }
                    continue
                }
                // Write new document first; only delete old if write succeeds.
                // 🔴 await 필수: 강화된 sharedAccess create 규칙은 inviteCode 없는 레거시 문서의
                // composite 생성을 거부한다. 비대기 setData 는 거부를 삼켜 catch 가 안 돌고,
                // 아래 delete 는 허용돼 레거시 원본이 지워진다 = 공유 소멸(데이터 손실).
                // await 로 거부를 잡아 continue → 레거시 원본을 보존한다.
                info.access.id = info.expectedId
                do {
                    try await newRef.setData(from: info.access)
                    do {
                        try await info.doc.reference.delete()
                    } catch {
                        logSilent("legacy doc 마이그레이션 후 삭제 실패: \(info.expectedId)", error: error, logger: AppLogger.firestore)
                    }
                } catch {
                    // Write rejected/failed — keep legacy doc, skip (재마이그레이션은 서버측에서).
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

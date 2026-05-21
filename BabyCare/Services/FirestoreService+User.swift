import FirebaseFirestore
import Foundation

/// AuthViewModel 의 계정 삭제 + 가족 공유 마이그레이션 narrow protocol (ISP).
///
/// 헤비 데이터 작업(서브컬렉션 일괄 삭제 / familySharing → sharedAccess 이관)을
/// FirestoreService 로 모아 AuthViewModel 에서 Firestore.firestore() 직접 호출 제거.
/// Mock 으로 호출 검증 가능.
protocol AuthMigrationProviding: Sendable {
    func deleteAllUserData(userId: String) async throws
    func migrateFamilySharingIfNeeded(userId: String) async
}

extension FirestoreService: AuthMigrationProviding {}

extension FirestoreService {
    // MARK: - User Metadata

    private static let lastAccessedAtKey = "BabyCare.lastAccessedAt.persistedAt"
    private static let lastAccessedAtThrottleSeconds: TimeInterval = 60 * 60

    /// 사용자 계정 삭제 시 서브컬렉션 전체 일괄 삭제 (원자적, 배치 500개 단위).
    /// "familySharing"(구형) + "sharedAccess"(신형) 모두 삭제.
    /// invites 컬렉션에서 내가 만든 초대도 삭제 후 users/{uid} 문서 자체 삭제.
    func deleteAllUserData(userId: String) async throws {
        let userDoc = db.collection(FirestoreCollections.users).document(userId)
        let subcollections = [
            "premiumStatus", FirestoreCollections.babies, FirestoreCollections.activities,
            FirestoreCollections.hospitalVisits, FirestoreCollections.vaccinations,
            FirestoreCollections.milestones, "diaryEntries", FirestoreCollections.todos,
            FirestoreCollections.routines, FirestoreCollections.products,
            "purchaseRecords", FirestoreCollections.sharedAccess, FirestoreCollections.familySharing
        ]
        var batch = db.batch()
        var count = 0
        for name in subcollections {
            let snapshot = try await userDoc.collection(name).getDocuments()
            for doc in snapshot.documents {
                batch.deleteDocument(doc.reference)
                count += 1
                if count >= 400 {
                    try await batch.commit()
                    batch = db.batch()
                    count = 0
                }
            }
        }

        let invites = try await db.collection(FirestoreCollections.invites)
            .whereField("ownerUserId", isEqualTo: userId)
            .getDocuments()
        for doc in invites.documents {
            batch.deleteDocument(doc.reference)
            count += 1
            if count >= 400 { try await batch.commit(); batch = db.batch(); count = 0 }
        }

        batch.deleteDocument(userDoc)
        try await batch.commit()
    }

    /// familySharing(구형) → sharedAccess(신형) 인라인 마이그레이션.
    /// 신형 문서가 이미 존재하면 setData 스킵, 구형은 항상 삭제. 실패 시 원자성 보장
    /// (batch 미커밋), 다음 로그인에 재시도.
    func migrateFamilySharingIfNeeded(userId: String) async {
        let userDoc = db.collection(FirestoreCollections.users).document(userId)
        let legacyRef = userDoc.collection(FirestoreCollections.familySharing)
        let newRef = userDoc.collection(FirestoreCollections.sharedAccess)

        do {
            let snapshot = try await legacyRef.getDocuments()
            guard !snapshot.documents.isEmpty else { return }

            // 신형 문서 존재 여부 병렬 일괄 확인 (String path 캡처로 Sendable 충족)
            let docIds = snapshot.documents.map { $0.documentID }
            let newRefPath = newRef.path
            let existingMap = await withTaskGroup(of: (String, Bool).self) { group in
                for docId in docIds {
                    group.addTask {
                        let ref = Firestore.firestore().collection(newRefPath).document(docId)
                        do {
                            let snap = try await ref.getDocument()
                            return (docId, snap.exists)
                        } catch {
                            logSilent("familySharing 신형 존재 확인 실패: \(docId)", error: error, logger: AppLogger.firestore)
                            return (docId, false)
                        }
                    }
                }
                var map: [String: Bool] = [:]
                for await (id, exists) in group { map[id] = exists }
                return map
            }

            let batch = db.batch()
            for doc in snapshot.documents {
                let newDocRef = newRef.document(doc.documentID)
                if !(existingMap[doc.documentID] ?? false) {
                    batch.setData(doc.data(), forDocument: newDocRef)
                }
                batch.deleteDocument(doc.reference)
            }
            try await batch.commit()
        } catch {
            // 원자성 보장 — 실패 시 아무것도 안 바뀜
        }
    }

    /// users/{uid}.lastAccessedAt 갱신. 어드민 "최근 접속일" 표시용.
    /// Firebase Auth metadata.lastSignInTime은 명시적 로그인에만 갱신되어 정확한 활동 추적 불가.
    /// 1시간 throttle로 쓰기 비용 제한.
    func updateLastAccessedAt(userId: String) async {
        if CommandLine.arguments.contains("UI_TESTING") { return }
        let now = Date()
        let lastPersisted = UserDefaults.standard.object(forKey: Self.lastAccessedAtKey) as? Date
        if let lastPersisted, now.timeIntervalSince(lastPersisted) < Self.lastAccessedAtThrottleSeconds {
            return
        }
        do {
            try await db.collection(FirestoreCollections.users)
                .document(userId)
                .setData(["lastAccessedAt": FieldValue.serverTimestamp()], merge: true)
            UserDefaults.standard.set(now, forKey: Self.lastAccessedAtKey)
        } catch {
            AppLogger.firestore.warning("updateLastAccessedAt failed: \(error.localizedDescription)")
        }
    }
}

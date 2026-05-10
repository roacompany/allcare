import FirebaseFirestore
import Foundation

extension FirestoreService {
    // MARK: - Pregnancy CRUD

    private func pregnancyRef(userId: String) -> CollectionReference {
        db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.pregnancies)
    }

    func savePregnancy(_ pregnancy: Pregnancy, userId: String) async throws {
        var updated = pregnancy
        updated.updatedAt = Date()
        try pregnancyRef(userId: userId).document(updated.id).setData(from: updated, merge: true)
    }

    func fetchActivePregnancy(userId: String) async throws -> Pregnancy? {
        let snapshot = try await pregnancyRef(userId: userId)
            .whereField("outcome", isEqualTo: PregnancyOutcome.ongoing.rawValue)
            .order(by: "createdAt", descending: true)
            .limit(to: 1)
            .getDocuments()
        return decodeDocuments(snapshot.documents, as: Pregnancy.self).first
    }

    func fetchArchivedPregnancies(userId: String) async throws -> [Pregnancy] {
        let snapshot = try await pregnancyRef(userId: userId)
            .whereField("outcome", isNotEqualTo: PregnancyOutcome.ongoing.rawValue)
            .order(by: "outcome")
            .order(by: "archivedAt", descending: true)
            .getDocuments()
        return decodeDocuments(snapshot.documents, as: Pregnancy.self)
    }

    func deletePregnancy(_ pregnancyId: String, userId: String) async throws {
        let ref = pregnancyRef(userId: userId).document(pregnancyId)
        // 하위 컬렉션 cascade 삭제
        let subcollections = [
            FirestoreCollections.kickSessions,
            FirestoreCollections.prenatalVisits,
            FirestoreCollections.pregnancyChecklists,
            FirestoreCollections.pregnancyWeights,
            FirestoreCollections.pregnancySymptoms
        ]
        for sub in subcollections {
            let docs = try await ref.collection(sub).getDocuments()
            for doc in docs.documents {
                try await doc.reference.delete()
            }
        }
        try await ref.delete()
    }

    // MARK: - Kick Session

    func saveKickSession(_ session: KickSession, userId: String, pregnancyId: String) async throws {
        try pregnancyRef(userId: userId)
            .document(pregnancyId)
            .collection(FirestoreCollections.kickSessions)
            .document(session.id)
            .setData(from: session, merge: true)
    }

    func fetchKickSessions(userId: String, pregnancyId: String, limit: Int = 30) async throws -> [KickSession] {
        let snapshot = try await pregnancyRef(userId: userId)
            .document(pregnancyId)
            .collection(FirestoreCollections.kickSessions)
            .order(by: "startedAt", descending: true)
            .limit(to: limit)
            .getDocuments()
        return decodeDocuments(snapshot.documents, as: KickSession.self)
    }

    // MARK: - Prenatal Visit

    func savePrenatalVisit(_ visit: PrenatalVisit, userId: String, pregnancyId: String) async throws {
        var updated = visit
        updated.updatedAt = Date()
        try pregnancyRef(userId: userId)
            .document(pregnancyId)
            .collection(FirestoreCollections.prenatalVisits)
            .document(updated.id)
            .setData(from: updated, merge: true)
    }

    func fetchPrenatalVisits(userId: String, pregnancyId: String) async throws -> [PrenatalVisit] {
        let snapshot = try await pregnancyRef(userId: userId)
            .document(pregnancyId)
            .collection(FirestoreCollections.prenatalVisits)
            .order(by: "scheduledAt", descending: false)
            .getDocuments()
        return decodeDocuments(snapshot.documents, as: PrenatalVisit.self)
    }

    // MARK: - Checklist

    func saveChecklistItem(_ item: PregnancyChecklistItem, userId: String, pregnancyId: String) async throws {
        try pregnancyRef(userId: userId)
            .document(pregnancyId)
            .collection(FirestoreCollections.pregnancyChecklists)
            .document(item.id)
            .setData(from: item, merge: true)
    }

    func fetchChecklistItems(userId: String, pregnancyId: String) async throws -> [PregnancyChecklistItem] {
        let snapshot = try await pregnancyRef(userId: userId)
            .document(pregnancyId)
            .collection(FirestoreCollections.pregnancyChecklists)
            .order(by: "order")
            .getDocuments()
        return decodeDocuments(snapshot.documents, as: PregnancyChecklistItem.self)
    }

    // MARK: - Weight

    func saveWeightEntry(_ entry: PregnancyWeightEntry, userId: String, pregnancyId: String) async throws {
        try pregnancyRef(userId: userId)
            .document(pregnancyId)
            .collection(FirestoreCollections.pregnancyWeights)
            .document(entry.id)
            .setData(from: entry, merge: true)
    }

    func fetchWeightEntries(userId: String, pregnancyId: String) async throws -> [PregnancyWeightEntry] {
        let snapshot = try await pregnancyRef(userId: userId)
            .document(pregnancyId)
            .collection(FirestoreCollections.pregnancyWeights)
            .order(by: "measuredAt", descending: false)
            .getDocuments()
        return decodeDocuments(snapshot.documents, as: PregnancyWeightEntry.self)
    }

    // MARK: - Symptoms

    func saveSymptom(_ symptom: PregnancySymptom, userId: String, pregnancyId: String) async throws {
        try pregnancyRef(userId: userId)
            .document(pregnancyId)
            .collection(FirestoreCollections.pregnancySymptoms)
            .document(symptom.id)
            .setData(from: symptom, merge: true)
    }

    func fetchSymptoms(userId: String, pregnancyId: String) async throws -> [PregnancySymptom] {
        let snapshot = try await pregnancyRef(userId: userId)
            .document(pregnancyId)
            .collection(FirestoreCollections.pregnancySymptoms)
            .order(by: "occurredAt", descending: true)
            .getDocuments()
        return decodeDocuments(snapshot.documents, as: PregnancySymptom.self)
    }

    // MARK: - Transition (WriteBatch + transitionState idempotency)

    /// Pregnancy → Baby 원자적 전환.
    /// WriteBatch로 3가지 쓰기를 원자화:
    ///   1. Pregnancy.transitionState = "completed"
    ///   2. Pregnancy.outcome = .born, archivedAt = now
    ///   3. Baby 신규 생성
    /// 하나라도 실패하면 Firestore가 전체 롤백.
    func transitionPregnancyToBaby(
        pregnancy: Pregnancy,
        newBaby: Baby,
        userId: String
    ) async throws {
        let batch = db.batch()

        // 1. Pregnancy 업데이트
        var archived = pregnancy
        archived.outcome = .born
        archived.archivedAt = Date()
        archived.transitionState = "completed"
        archived.updatedAt = Date()
        let pRef = pregnancyRef(userId: userId).document(archived.id)
        try batch.setData(from: archived, forDocument: pRef, merge: true)

        // 2. Baby 생성
        let bRef = db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.babies)
            .document(newBaby.id)
        try batch.setData(from: newBaby, forDocument: bRef, merge: false)

        try await batch.commit()
    }

    /// 전환 실패 복구용: transitionState=pending 상태에서 재시도 시 호출.
    func markTransitionPending(_ pregnancyId: String, userId: String) async throws {
        let ref = pregnancyRef(userId: userId).document(pregnancyId)
        try await ref.setData(["transitionState": "pending", "updatedAt": Date()], merge: true)
    }

    /// pending 전환 취소: transitionState 필드 제거, ongoing 유지. 문서 삭제 금지.
    /// 취소 시 사용자 데이터 보존 필수 — deletePregnancy 사용 금지.
    func rollbackTransitionPending(_ pregnancyId: String, userId: String) async throws {
        let ref = pregnancyRef(userId: userId).document(pregnancyId)
        try await ref.updateData([
            "transitionState": FieldValue.delete(),
            "updatedAt": Date()
        ])
    }

    /// 임신 종료 (유산/사산/임신중지) WriteBatch 전환.
    /// markTransitionPending 호출 후 이 메서드로 진입 (P0-3 Scenario c 채택).
    /// WriteBatch로 2가지 쓰기를 원자화:
    ///   1. Pregnancy.outcome = outcome (miscarriage/stillbirth/terminated)
    ///   2. Pregnancy.transitionState = "completed", archivedAt = now
    /// 단일 write 금지 — WriteBatch + transitionState 필수 (safety.md).
    func terminatePregnancy(
        pregnancy: Pregnancy,
        outcome: PregnancyOutcome,
        userId: String
    ) async throws {
        precondition(
            outcome == .miscarriage || outcome == .stillbirth || outcome == .terminated,
            "terminatePregnancy는 종료 outcome만 허용 (born은 transitionPregnancyToBaby 사용)"
        )
        let batch = db.batch()

        var archived = pregnancy
        archived.outcome = outcome
        archived.archivedAt = Date()
        archived.transitionState = "completed"
        archived.updatedAt = Date()
        let pRef = pregnancyRef(userId: userId).document(archived.id)
        try batch.setData(from: archived, forDocument: pRef, merge: true)

        try await batch.commit()
    }

    // MARK: - Partner Sharing

    /// 이메일로 사용자 UID 조회 후 sharedWith에 추가 (읽기 전용 공유).
    func addPregnancyPartner(email: String, userId: String, pregnancyId: String) async throws {
        // 이메일로 UID 조회 (users 컬렉션에서 email 필드 검색).
        let snapshot = try await db.collection(FirestoreCollections.users)
            .whereField("email", isEqualTo: email)
            .limit(to: 1)
            .getDocuments()
        guard let partnerDoc = snapshot.documents.first else {
            throw NSError(domain: "PregnancyShare", code: 404,
                          userInfo: [NSLocalizedDescriptionKey: "해당 이메일의 사용자를 찾을 수 없습니다."])
        }
        let partnerUid = partnerDoc.documentID
        let ref = pregnancyRef(userId: userId).document(pregnancyId)
        try await ref.updateData(["sharedWith": FieldValue.arrayUnion([partnerUid]),
                                  "updatedAt": Date()])
    }

    /// sharedWith에서 파트너 UID 제거.
    func removePregnancyPartner(partnerUid: String, userId: String, pregnancyId: String) async throws {
        let ref = pregnancyRef(userId: userId).document(pregnancyId)
        try await ref.updateData(["sharedWith": FieldValue.arrayRemove([partnerUid]),
                                  "updatedAt": Date()])
    }

    // MARK: - Partner Shared Pregnancy (collectionGroup)

    /// 파트너가 나를 sharedWith에 포함시킨 진행 중 임신 조회.
    /// collectionGroup("pregnancies")로 모든 사용자 하위 pregnancies 서브컬렉션을 검색.
    /// PregnancyViewModel.loadActivePregnancy에서 자신의 임신이 없을 때 fallback으로 호출.
    func fetchSharedPregnancy(currentUserId: String) async throws -> Pregnancy? {
        let snapshot = try await db
            .collectionGroup(FirestoreCollections.pregnancies)
            .whereField("sharedWith", arrayContains: currentUserId)
            .whereField("outcome", isEqualTo: PregnancyOutcome.ongoing.rawValue)
            .limit(to: 1)
            .getDocuments()
        return decodeDocuments(snapshot.documents, as: Pregnancy.self).first
    }
}

// WriteBatch Codable 지원을 위한 헬퍼 (Firestore SDK가 기본 제공하지 않음).
private extension WriteBatch {
    func setData<T: Encodable>(from value: T, forDocument reference: DocumentReference, merge: Bool = false) throws {
        let data = try Firestore.Encoder().encode(value)
        self.setData(data, forDocument: reference, merge: merge)
    }
}

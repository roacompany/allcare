import FirebaseFirestore
import Foundation

extension FirestoreService {
        // MARK: - Baby

    /// 신규 아기 생성 — WriteBatch로 baby 문서 + users/{uid}.babyCount +1 원자화.
    /// admin 데이터 정확성을 위한 denormalized counter (admin은 N+1 회피용으로 읽음).
    func createBaby(_ baby: Baby, userId: String) async throws {
        let userRef = db.collection(FirestoreCollections.users).document(userId)
        let babyRef = userRef
            .collection(FirestoreCollections.babies)
            .document(baby.id)

        let batch = db.batch()
        try batch.setData(from: baby, forDocument: babyRef)
        batch.setData(
            ["babyCount": FieldValue.increment(Int64(1))],
            forDocument: userRef,
            merge: true
        )
        try await batch.commit()
    }

    /// 기존 아기 정보 업데이트 — babyCount 변동 없음.
    func updateBaby(_ baby: Baby, userId: String) async throws {
        let ref = db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.babies)
            .document(baby.id)
        try ref.setData(from: baby, merge: true)
    }

    func fetchBabies(userId: String) async throws -> [Baby] {
        let snapshot = try await db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.babies)
            .order(by: "createdAt", descending: false)
            .getDocuments()
        return decodeDocuments(snapshot.documents, as: Baby.self)
    }

    /// Baby 삭제 시 하위 컬렉션(`FirestoreCollections.babyChildren` 전부 — 여행 포함)도 함께 삭제.
    /// 삭제 완료 후 users/{uid}.babyCount -1.
    func deleteBaby(_ babyId: String, userId: String) async throws {
        let userRef = db.collection(FirestoreCollections.users).document(userId)
        let babyRef = userRef
            .collection(FirestoreCollections.babies)
            .document(babyId)

        // 하위 컬렉션 cascade 삭제 — 목록은 한 곳(babyChildren). 여기 손으로 적던 목록은 trips 를 빠뜨렸다(2026-11-14).
        for child in FirestoreCollections.babyChildren {
            try await deleteAllDocuments(in: babyRef.collection(child))
        }

        try await babyRef.delete()

        // user doc의 babyCount -1 (denormalized counter)
        try await userRef.setData(
            ["babyCount": FieldValue.increment(Int64(-1))],
            merge: true
        )

        // 이 아기의 내 초대도 지운다(아기 이름이 든 개인정보 · 남겨 두면 받은 사람이 빈 아기 공유에 들어간다).
        // 「내 초대」 목록 규칙(2026-11-14 보완)이 배포되기 전엔 막히므로 실패해도 아기 삭제는 끝난 것으로 본다.
        await deleteMyInvitesBestEffort(ownerUserId: userId, babyId: babyId)
    }
}

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

    /// Baby 삭제 시 하위 컬렉션(activities, growth, diary 등)도 함께 삭제.
    /// 삭제 완료 후 users/{uid}.babyCount -1.
    func deleteBaby(_ babyId: String, userId: String) async throws {
        let userRef = db.collection(FirestoreCollections.users).document(userId)
        let babyRef = userRef
            .collection(FirestoreCollections.babies)
            .document(babyId)

        // 하위 컬렉션 cascade 삭제
        let subcollections = [
            FirestoreCollections.activities,
            FirestoreCollections.growth,
            FirestoreCollections.diary,
            FirestoreCollections.vaccinations,
            FirestoreCollections.milestones,
            FirestoreCollections.hospitalVisits,
            FirestoreCollections.purchases,
            FirestoreCollections.hospitalReports
        ]
        for subcollection in subcollections {
            let docs = try await babyRef.collection(subcollection).getDocuments()
            for doc in docs.documents {
                try await doc.reference.delete()
            }
        }

        try await babyRef.delete()

        // user doc의 babyCount -1 (denormalized counter)
        try await userRef.setData(
            ["babyCount": FieldValue.increment(Int64(-1))],
            merge: true
        )

        // 해당 아기의 초대 코드도 정리
        let invites = try await db.collection(FirestoreCollections.invites)
            .whereField("ownerUserId", isEqualTo: userId)
            .whereField("babyId", isEqualTo: babyId)
            .getDocuments()
        for doc in invites.documents {
            try await doc.reference.delete()
        }
    }
}

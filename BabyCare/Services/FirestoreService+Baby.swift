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

        // 1. 이 아기의 내 초대부터 — 아기 이름이 든 개인정보이고, 남기면 받은 사람이 빈 아기 공유에 들어간다.
        //    아기 문서를 지운 뒤엔 실패해도 다시 지울 길이 없다(아기가 목록에서 사라진다) → 맨 앞에서, 실패하면 아무것도 안 지운 채 멈춘다.
        //    「내 초대 목록」 규칙 배포 전(권한 거부)만 넘긴다 — 계정 삭제와 같은 판정(2026-11-14 재검토).
        do {
            try await deleteMyInvites(ownerUserId: userId, babyId: babyId)
        } catch {
            guard Self.mayIgnoreInviteCleanupFailure(error) else { throw error }
            logSilent("내 초대 목록이 막힘(규칙 배포 전) — 아기 삭제는 계속", error: error, logger: AppLogger.firestore)
        }

        // 2. 하위 컬렉션 cascade 삭제 — 목록은 한 곳(babyChildren). 여기 손으로 적던 목록은 trips 를 빠뜨렸다(2026-11-14).
        for child in FirestoreCollections.babyChildren {
            try await deleteAllDocuments(in: babyRef.collection(child))
        }

        // 3. 아기 문서 — 시간 초과는 「지움」으로 본다: 아래는 이미 다 지웠고, 지우기는 기기 줄에 남아 망이 돌아오면 간다.
        //    실패로 알리면 텅 빈 아기가 목록에 돌아왔다가 망이 돌아오면 사라진다(2026-11-14 재검토). 거부 등 다른 실패는 던진다.
        do {
            try await deleteConfirmed(babyRef)
        } catch ServerConfirmationError.timedOut {
            logSilent("아기 문서 지우기 답 없음 — 기기 줄에 남아 망이 돌아오면 지워진다", logger: AppLogger.firestore)
        }

        // 4. user doc의 babyCount -1 (denormalized counter) — 아기는 이미 지워졌다: 여기 실패는 기록만 한다.
        // 전엔 던져서 화면이 지운 아기를 다시 띄우고 사진 정리를 건너뛰었다(2026-11-14 검토).
        do {
            try await Self.awaitServerConfirmation { done in
                userRef.setData(["babyCount": FieldValue.increment(Int64(-1))], merge: true, completion: done)
            }
        } catch {
            logSilent("아기 수 줄이기 실패(아기 삭제는 끝남)", error: error, logger: AppLogger.firestore)
        }
    }
}

import FirebaseFirestore
import Foundation

extension FirestoreService {
    /// 한 번에 묶어 지우는 문서 수(Firestore 묶음 한도 500 보다 여유 있게).
    static let eraseBatchSize = 400

    /// 컬렉션(또는 조건 목록)에 걸리는 문서를 전부 지우고 지운 수를 돌려준다.
    /// - 목록은 **서버에서** 읽는다 — 기기 캐시만 보면 캐시에 없는 기록이 남는다(지우기는 다 지워야 한다).
    ///   오프라인이면 던진다 → 부른 쪽이 「실패」로 알린다.
    /// - 한 건씩 서버를 기다리면 기록이 많은 아기는 몇 분 걸린다 → 400개씩 묶어 지운다.
    /// - 하위 컬렉션은 지우지 않는다(Firestore 는 문서를 지워도 그 아래를 남긴다) — 부른 쪽이 따로 부른다.
    @discardableResult
    func deleteAllDocuments(in query: Query) async throws -> Int {
        let snapshot = try await query.getDocuments(source: .server)
        var batch = db.batch()
        var pending = 0
        for document in snapshot.documents {
            batch.deleteDocument(document.reference)
            pending += 1
            if pending == Self.eraseBatchSize {
                try await batch.commit()
                batch = db.batch()
                pending = 0
            }
        }
        if pending > 0 {
            try await batch.commit()
        }
        return snapshot.documents.count
    }

    /// 내가 만든 초대를 지운다(아기 하나 또는 전부). 초대엔 아기 이름이 있다 — 만료는 「못 씀」일 뿐 지우지 않고,
    /// 무료 요금제라 TTL 도 없다(2026-11-10) → 아기·계정을 지울 때 같이 지운다.
    /// 목록은 「내 초대」 조건으로만 열린다(firestore.rules 2026-11-14 보완). 그 규칙이 배포되기 전엔 목록이 막혀 던진다
    /// → 부르는 쪽은 실패해도 아기·계정 삭제를 멈추지 않는다.
    @discardableResult
    func deleteMyInvites(ownerUserId: String, babyId: String? = nil) async throws -> Int {
        var mine: Query = db.collection(FirestoreCollections.invites)
            .whereField("ownerUserId", isEqualTo: ownerUserId)
        if let babyId {
            mine = mine.whereField("babyId", isEqualTo: babyId)
        }
        return try await deleteAllDocuments(in: mine)
    }

    /// `deleteMyInvites` 를 부르되 실패는 기록만 하고 넘어간다(규칙 보완 배포 전 · 네트워크).
    func deleteMyInvitesBestEffort(ownerUserId: String, babyId: String? = nil) async {
        do {
            try await deleteMyInvites(ownerUserId: ownerUserId, babyId: babyId)
        } catch {
            logSilent("내 초대 정리 실패(삭제는 계속)", error: error, logger: AppLogger.firestore)
        }
    }
}

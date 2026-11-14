import FirebaseFirestore
import Foundation

extension FirestoreService {
    /// 한 번에 묶어 지우는 문서 수(Firestore 묶음 한도 500 보다 여유 있게).
    static let eraseBatchSize = 400

    /// 컬렉션 안 문서를 전부 지우고 지운 수를 돌려준다.
    /// - 목록은 **서버에서** 읽는다 — 기기 캐시만 보면 캐시에 없는 기록이 남는다(지우기는 다 지워야 한다).
    ///   오프라인이면 던진다 → 부른 쪽이 「실패」로 알린다.
    /// - 한 건씩 서버를 기다리면 기록이 많은 아기는 몇 분 걸린다 → 400개씩 묶어 지운다.
    /// - 하위 컬렉션은 지우지 않는다(Firestore 는 문서를 지워도 그 아래를 남긴다) — 부른 쪽이 따로 부른다.
    @discardableResult
    func deleteAllDocuments(in collection: CollectionReference) async throws -> Int {
        let snapshot = try await collection.getDocuments(source: .server)
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
}

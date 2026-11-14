import Foundation
import FirebaseFirestore

final class FirestoreService: Sendable {
    static let shared = FirestoreService()
    nonisolated(unsafe) let db: Firestore

    private init() {
        db = Firestore.firestore()
    }

    /// 다른 Firestore(시험의 로컬 에뮬레이터)로 같은 코드를 돌리는 입구. 실제 앱은 `shared` 만 쓴다.
    /// ⚠️ 이 타입 안에서는 `Firestore.firestore()` 대신 늘 `db` 를 쓸 것 — 직접 부르면 이 입구를 우회해 운영 서버로 간다.
    init(db: Firestore) {
        self.db = db
    }

    /// Firestore 문서 배열 디코딩. 개별 실패는 로깅 후 스킵.
    func decodeDocuments<T: Decodable>(_ documents: [QueryDocumentSnapshot], as type: T.Type) -> [T] {
        documents.compactMap { doc in
            do {
                return try doc.data(as: T.self)
            } catch {
                AppLogger.firestore.warning("Document \(doc.documentID) decode failed: \(error.localizedDescription)")
                return nil
            }
        }
    }
}

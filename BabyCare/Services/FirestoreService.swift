import Foundation
import FirebaseFirestore
import OSLog

final class FirestoreService: Sendable {
    static let shared = FirestoreService()
    nonisolated(unsafe) let db = Firestore.firestore()
    static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "BabyCare", category: "Firestore")

    private init() {}

    /// Firestore 문서 배열 디코딩. 개별 실패는 로깅 후 스킵.
    func decodeDocuments<T: Decodable>(_ documents: [QueryDocumentSnapshot], as type: T.Type) -> [T] {
        documents.compactMap { doc in
            do {
                return try doc.data(as: T.self)
            } catch {
                Self.logger.warning("Document \(doc.documentID) decode failed: \(error.localizedDescription)")
                return nil
            }
        }
    }
}

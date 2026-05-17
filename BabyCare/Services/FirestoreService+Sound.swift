import FirebaseFirestore
import Foundation

/// SoundLibraryService 가 의존하는 사운드 트랙 fetch narrow protocol (ISP).
/// sounds 컬렉션은 top-level. sortOrder 오름차순 정렬 후 반환.
protocol SoundFirestoreProviding: Sendable {
    func fetchSoundTracks() async throws -> [SoundTrack]
}

extension FirestoreService: SoundFirestoreProviding {}

extension FirestoreService {
    // MARK: - Sound Tracks

    /// 사운드 트랙 목록 fetch. 개별 decode 실패는 경고 후 skip (decodeDocuments).
    /// 반환 비어있으면 호출자는 fallback 적용.
    func fetchSoundTracks() async throws -> [SoundTrack] {
        let snapshot = try await db.collection(FirestoreCollections.sounds)
            .order(by: "sortOrder")
            .getDocuments()
        return decodeDocuments(snapshot.documents, as: SoundTrack.self)
    }
}

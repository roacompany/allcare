import Foundation
@testable import BabyCare

/// SoundLibraryService 흐름 테스트용 Mock.
/// Firestore 비어있음 / 실패 / 정상 fallback 시나리오 검증.
final class MockSoundFirestore: SoundFirestoreProviding, @unchecked Sendable {
    var stubTracks: [SoundTrack] = []
    var errorOnFetch: Error?
    private(set) var fetchCallCount = 0

    func fetchSoundTracks() async throws -> [SoundTrack] {
        fetchCallCount += 1
        if let err = errorOnFetch { throw err }
        return stubTracks
    }
}

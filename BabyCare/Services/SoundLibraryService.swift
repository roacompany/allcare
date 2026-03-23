import Foundation
import FirebaseFirestore
import OSLog

// MARK: - SoundLibraryService
// Firestore `sounds` 컬렉션에서 트랙 목록을 가져오고 로컬 캐시로 관리합니다.

@MainActor @Observable
final class SoundLibraryService {
    static let shared = SoundLibraryService()

    // MARK: - 상태

    var tracks: [SoundTrack] = []
    var isLoading = false
    var errorMessage: String?

    // 카테고리별 그룹핑 (sortPriority 순)
    var groupedTracks: [(SoundTrack.SoundTrackCategory, [SoundTrack])] {
        let sorted = SoundTrack.SoundTrackCategory.allCases
            .sorted { $0.sortPriority < $1.sortPriority }
        return sorted.compactMap { cat in
            let items = tracks.filter { $0.category == cat }
                .sorted { $0.sortOrder < $1.sortOrder }
            return items.isEmpty ? nil : (cat, items)
        }
    }

    // MARK: - Private

    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "BabyCare", category: "SoundLibrary")
    private let db = Firestore.firestore()

    /// UserDefaults 캐시 키
    private let cacheKey = "sound_library_cache_v1"

    private init() {}

    // MARK: - 공개 API

    /// Firestore에서 트랙 목록 가져오기. 실패 시 캐시 → 기본값 순서로 폴백.
    func fetchTracks() async {
        isLoading = true
        errorMessage = nil

        // 1) Firestore 시도
        do {
            let snapshot = try await db.collection("sounds")
                .order(by: "sortOrder")
                .getDocuments()

            let fetched: [SoundTrack] = snapshot.documents.compactMap { doc in
                do {
                    return try doc.data(as: SoundTrack.self)
                } catch {
                    Self.logger.warning("Decode failed \(doc.documentID): \(error.localizedDescription)")
                    return nil
                }
            }

            if !fetched.isEmpty {
                tracks = fetched
                saveCache(fetched)
                Self.logger.info("Fetched \(fetched.count) tracks from Firestore")
            } else {
                // Firestore에 데이터 없음 → 기본값 사용
                tracks = SoundTrack.fallbackTracks
                Self.logger.info("Firestore empty — using fallback tracks")
            }
        } catch {
            Self.logger.error("Firestore fetch failed: \(error.localizedDescription)")
            errorMessage = "트랙 목록을 불러오지 못했습니다."

            // 2) 캐시 시도
            if let cached = loadCache(), !cached.isEmpty {
                tracks = cached
                Self.logger.info("Using cached \(cached.count) tracks")
            } else {
                // 3) 기본 폴백
                tracks = SoundTrack.fallbackTracks
                Self.logger.info("Using fallback tracks")
            }
        }

        isLoading = false
    }

    // MARK: - 캐시 (UserDefaults JSON)

    private func saveCache(_ items: [SoundTrack]) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: cacheKey)
    }

    private func loadCache() -> [SoundTrack]? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let items = try? JSONDecoder().decode([SoundTrack].self, from: data)
        else { return nil }
        return items
    }
}

// MARK: - 기본 폴백 데이터 (기존 10개 로컬 사운드)

extension SoundTrack {
    static nonisolated(unsafe) let fallbackTracks: [SoundTrack] = {
        SoundItem.all.enumerated().map { index, item in
            SoundTrack(
                id: item.id,
                name: item.name,
                artist: "BabyCare",
                category: item.category.toSoundTrackCategory,
                duration: 0,
                storageURL: "",
                iconName: item.icon,
                isFree: true,
                sortOrder: index,
                isLocal: true,
                localFileName: item.fileName
            )
        }
    }()
}

private extension SoundItem.SoundCategory {
    var toSoundTrackCategory: SoundTrack.SoundTrackCategory {
        switch self {
        case .whiteNoise: .whiteNoise
        case .nature:     .nature
        case .life:       .life
        case .music:      .lullaby
        }
    }
}

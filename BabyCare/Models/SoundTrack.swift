import Foundation
import FirebaseFirestore

// MARK: - SoundTrack 모델 (Firebase Storage 스트리밍용)

struct SoundTrack: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var name: String
    var artist: String
    var category: SoundTrackCategory
    var duration: Int          // 초 단위
    var storageURL: String     // Firebase Storage gs:// 경로 또는 https:// URL
    var iconName: String       // SF Symbol 이름
    var isFree: Bool
    var sortOrder: Int
    var isLocal: Bool          // true면 Bundle에서 로컬 재생 (기존 10개)
    var localFileName: String? // isLocal == true일 때 Bundle 파일명

    // MARK: - Category

    enum SoundTrackCategory: String, Codable, CaseIterable {
        case whiteNoise = "백색소음"
        case nature     = "자연"
        case life       = "생활"
        case mozart     = "클래식-모차르트"
        case bach       = "클래식-바흐"
        case chopin     = "클래식-쇼팽"
        case debussy    = "클래식-드뷔시"
        case classicEtc = "클래식-기타"
        case lullaby    = "자장가"

        var icon: String {
            switch self {
            case .whiteNoise: "waveform"
            case .nature:     "leaf.fill"
            case .life:       "house.fill"
            case .mozart:     "music.note"
            case .bach:       "music.quarternote.3"
            case .chopin:     "pianokeys.inverse"
            case .debussy:    "water.waves"
            case .classicEtc: "music.note.list"
            case .lullaby:    "moon.stars.fill"
            }
        }

        var displayName: String { rawValue }

        // 화면 표시 순서
        var sortPriority: Int {
            switch self {
            case .whiteNoise: 0
            case .nature:     1
            case .life:       2
            case .lullaby:    3
            case .mozart:     4
            case .bach:       5
            case .chopin:     6
            case .debussy:    7
            case .classicEtc: 8
            }
        }
    }

    // MARK: - 재생 시간 표시용

    var durationText: String {
        let m = duration / 60
        let s = duration % 60
        return String(format: "%d:%02d", m, s)
    }
}

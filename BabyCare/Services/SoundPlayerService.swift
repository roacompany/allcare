import AVFoundation
import FirebaseStorage
import OSLog

// MARK: - SoundPlayerService
// 로컬(AVAudioPlayer) 및 스트리밍(AVPlayer) 재생을 모두 지원합니다.

@MainActor @Observable
final class SoundPlayerService {
    static let shared = SoundPlayerService()

    // MARK: - 공개 상태

    var isPlaying = false
    var currentSound: SoundItem?       // 기존 로컬 사운드 (하위 호환)
    var currentTrack: SoundTrack?      // 새 스트리밍 트랙
    var volume: Float = 0.7
    var remainingSeconds: Int?
    var isBuffering = false            // 스트리밍 버퍼링 중
    var downloadProgress: Double = 0   // 0.0 ~ 1.0

    // MARK: - Private

    private var localPlayer: AVAudioPlayer?
    private var streamPlayer: AVPlayer?
    private var streamObserver: NSKeyValueObservation?
    private var timer: Timer?

    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "BabyCare", category: "SoundPlayer")

    /// 로컬 캐시 디렉터리 (다운로드한 트랙 저장)
    private static let cacheDirectory: URL = {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SoundCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private init() {}

    // MARK: - 기존 로컬 재생 (하위 호환)

    func play(_ sound: SoundItem) {
        stopAll()

        guard let url = sound.fileURL else {
            Self.logger.warning("Sound file not found: \(sound.fileName)")
            return
        }

        activateAudioSession()

        do {
            localPlayer = try AVAudioPlayer(contentsOf: url)
            localPlayer?.numberOfLoops = -1 // 무한 반복
            localPlayer?.volume = volume
            localPlayer?.play()

            currentSound = sound
            currentTrack = nil
            isPlaying = true
        } catch {
            Self.logger.error("Failed to play local sound: \(error.localizedDescription)")
        }
    }

    // MARK: - 스트리밍 재생

    /// SoundTrack 재생. isLocal == true면 Bundle에서, 아니면 Firebase Storage URL로 스트리밍.
    func play(_ track: SoundTrack) {
        // 로컬 트랙인 경우 기존 방식으로 처리
        if track.isLocal, let fileName = track.localFileName {
            let fallback = SoundItem(
                id: track.id ?? UUID().uuidString,
                name: track.name,
                icon: track.iconName,
                fileName: fileName,
                category: .music
            )
            play(fallback)
            // currentTrack도 세팅하여 UI가 SoundTrack 기반으로 표시 가능하게
            currentTrack = track
            return
        }

        stopAll()
        isBuffering = true

        // 1) 로컬 캐시 확인
        if let cachedURL = cachedURL(for: track) {
            playFromURL(cachedURL, track: track)
            return
        }

        // 2) Firebase Storage URL 가져와서 스트리밍
        Task {
            do {
                let url = try await resolveStreamURL(track: track)
                playFromURL(url, track: track)
            } catch {
                Self.logger.error("Stream URL resolve failed: \(error.localizedDescription)")
                isBuffering = false
            }
        }
    }

    private func playFromURL(_ url: URL, track: SoundTrack) {
        activateAudioSession()

        let item = AVPlayerItem(url: url)
        streamPlayer = AVPlayer(playerItem: item)
        streamPlayer?.volume = volume

        // 버퍼링 감지
        streamObserver = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch item.status {
                case .readyToPlay:
                    self.isBuffering = false
                    self.streamPlayer?.play()
                    self.isPlaying = true
                case .failed:
                    self.isBuffering = false
                    Self.logger.error("AVPlayerItem failed: \(item.error?.localizedDescription ?? "unknown")")
                default:
                    break
                }
            }
        }

        // 재생 종료 시 반복
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.streamPlayer?.seek(to: .zero)
                self?.streamPlayer?.play()
            }
        }

        currentTrack = track
        currentSound = nil
    }

    // MARK: - Firebase Storage URL 해결

    private func resolveStreamURL(track: SoundTrack) async throws -> URL {
        let rawURL = track.storageURL

        // 이미 https:// URL이면 그대로 사용
        if rawURL.hasPrefix("https://") || rawURL.hasPrefix("http://") {
            guard let url = URL(string: rawURL) else {
                throw URLError(.badURL)
            }
            return url
        }

        // gs:// 경로라면 Firebase Storage에서 다운로드 URL 획득
        let storage = Storage.storage()
        let ref: StorageReference

        if rawURL.hasPrefix("gs://") {
            ref = storage.reference(forURL: rawURL)
        } else {
            ref = storage.reference().child(rawURL)
        }

        let downloadURL = try await ref.downloadURL()
        return downloadURL
    }

    // MARK: - 다운로드 (캐시)

    func downloadTrack(_ track: SoundTrack) async {
        guard !track.isLocal else { return }
        guard cachedURL(for: track) == nil else { return } // 이미 캐시됨

        downloadProgress = 0

        do {
            let url = try await resolveStreamURL(track: track)
            let (data, _) = try await URLSession.shared.data(from: url)
            let dest = cacheFileURL(for: track)
            try data.write(to: dest)
            downloadProgress = 1.0
            Self.logger.info("Downloaded track: \(track.name)")
        } catch {
            Self.logger.error("Download failed for \(track.name): \(error.localizedDescription)")
            downloadProgress = 0
        }
    }

    func isDownloaded(_ track: SoundTrack) -> Bool {
        cachedURL(for: track) != nil
    }

    func deleteCache(_ track: SoundTrack) {
        let file = cacheFileURL(for: track)
        try? FileManager.default.removeItem(at: file)
    }

    // MARK: - 공통 제어

    func stop() {
        stopAll()
    }

    func togglePlayPause() {
        if let localPlayer {
            if localPlayer.isPlaying {
                localPlayer.pause()
                isPlaying = false
            } else {
                localPlayer.play()
                isPlaying = true
            }
        } else if let streamPlayer {
            if isPlaying {
                streamPlayer.pause()
                isPlaying = false
            } else {
                streamPlayer.play()
                isPlaying = true
            }
        }
    }

    func setVolume(_ value: Float) {
        volume = value
        localPlayer?.volume = value
        streamPlayer?.volume = value
    }

    // MARK: - Sleep Timer

    func startTimer(minutes: Int) {
        cancelTimer()
        remainingSeconds = minutes * 60

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if let remaining = self.remainingSeconds, remaining > 0 {
                    self.remainingSeconds = remaining - 1
                } else {
                    self.stop()
                }
            }
        }
    }

    func cancelTimer() {
        timer?.invalidate()
        timer = nil
        remainingSeconds = nil
    }

    var timerText: String? {
        guard let seconds = remainingSeconds else { return nil }
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }

    // MARK: - 현재 재생 정보 (통합)

    /// FloatingMiniPlayer 등에서 쓸 수 있는 통합 표시 이름
    var currentName: String? {
        currentTrack?.name ?? currentSound?.name
    }

    var currentIcon: String? {
        currentTrack?.iconName ?? currentSound?.icon
    }

    // MARK: - Private Helpers

    private func stopAll() {
        localPlayer?.stop()
        localPlayer = nil

        streamPlayer?.pause()
        streamPlayer = nil
        streamObserver = nil
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)

        isPlaying = false
        isBuffering = false
        currentSound = nil
        currentTrack = nil
        cancelTimer()

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func activateAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            Self.logger.error("AVAudioSession activation failed: \(error.localizedDescription)")
        }
    }

    private func cacheFileURL(for track: SoundTrack) -> URL {
        let safeID = (track.id ?? UUID().uuidString)
            .replacingOccurrences(of: "/", with: "_")
        return Self.cacheDirectory.appendingPathComponent("\(safeID).m4a")
    }

    private func cachedURL(for track: SoundTrack) -> URL? {
        let url = cacheFileURL(for: track)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
}

// MARK: - Sound Item (기존 로컬 10개 — 하위 호환 유지)

struct SoundItem: Identifiable, Hashable {
    let id: String
    let name: String
    let icon: String
    let fileName: String
    let category: SoundCategory

    var fileURL: URL? {
        Bundle.main.url(forResource: fileName, withExtension: nil)
    }

    enum SoundCategory: String, CaseIterable {
        case whiteNoise = "백색소음"
        case nature = "자연"
        case life = "생활"
        case music = "음악"

        var icon: String {
            switch self {
            case .whiteNoise: "waveform"
            case .nature:     "leaf.fill"
            case .life:       "house.fill"
            case .music:      "music.note"
            }
        }
    }

    static let all: [SoundItem] = [
        // 백색소음
        SoundItem(id: "white_noise",  name: "화이트 노이즈", icon: "waveform",             fileName: "white_noise.wav",  category: .whiteNoise),
        SoundItem(id: "pink_noise",   name: "핑크 노이즈",   icon: "waveform.badge.minus", fileName: "pink_noise.wav",   category: .whiteNoise),
        // 자연
        SoundItem(id: "rain",         name: "빗소리",        icon: "cloud.rain.fill",       fileName: "rain.wav",         category: .nature),
        SoundItem(id: "ocean",        name: "파도소리",       icon: "water.waves",           fileName: "ocean.wav",        category: .nature),
        SoundItem(id: "birds",        name: "새소리",        icon: "bird.fill",             fileName: "birds.wav",        category: .nature),
        // 생활
        SoundItem(id: "heartbeat",    name: "심장박동",       icon: "heart.fill",            fileName: "heartbeat.wav",    category: .life),
        SoundItem(id: "fan",          name: "선풍기",        icon: "fan.fill",              fileName: "fan.wav",          category: .life),
        SoundItem(id: "shushing",     name: "쉬 소리",       icon: "mouth.fill",            fileName: "shushing.wav",     category: .life),
        // 음악
        SoundItem(id: "lullaby",      name: "자장가",        icon: "moon.stars.fill",       fileName: "lullaby.wav",      category: .music),
        SoundItem(id: "music_box",    name: "오르골",        icon: "music.note.list",       fileName: "music_box.wav",    category: .music),
    ]

    static func byCategory() -> [(SoundItem.SoundCategory, [SoundItem])] {
        SoundCategory.allCases.compactMap { cat in
            let items = all.filter { $0.category == cat }
            return items.isEmpty ? nil : (cat, items)
        }
    }
}

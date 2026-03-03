import AVFoundation
import OSLog

@MainActor @Observable
final class SoundPlayerService {
    static let shared = SoundPlayerService()

    var isPlaying = false
    var currentSound: SoundItem?
    var volume: Float = 0.7
    var remainingSeconds: Int?

    private var player: AVAudioPlayer?
    private var timer: Timer?
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "BabyCare", category: "SoundPlayer")

    private init() {}

    func play(_ sound: SoundItem) {
        stop()

        guard let url = sound.fileURL else {
            Self.logger.warning("Sound file not found: \(sound.fileName)")
            return
        }

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)

            player = try AVAudioPlayer(contentsOf: url)
            player?.numberOfLoops = -1 // 무한 반복
            player?.volume = volume
            player?.play()

            currentSound = sound
            isPlaying = true
        } catch {
            Self.logger.error("Failed to play sound: \(error.localizedDescription)")
        }
    }

    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
        currentSound = nil
        cancelTimer()

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func togglePlayPause() {
        guard let player else { return }
        if player.isPlaying {
            player.pause()
            isPlaying = false
        } else {
            player.play()
            isPlaying = true
        }
    }

    func setVolume(_ value: Float) {
        volume = value
        player?.volume = value
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
}

// MARK: - Sound Item

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
            case .nature: "leaf.fill"
            case .life: "house.fill"
            case .music: "music.note"
            }
        }
    }

    static let all: [SoundItem] = [
        // 백색소음
        SoundItem(id: "white_noise", name: "화이트 노이즈", icon: "waveform", fileName: "white_noise.wav", category: .whiteNoise),
        SoundItem(id: "pink_noise", name: "핑크 노이즈", icon: "waveform.badge.minus", fileName: "pink_noise.wav", category: .whiteNoise),
        // 자연
        SoundItem(id: "rain", name: "빗소리", icon: "cloud.rain.fill", fileName: "rain.wav", category: .nature),
        SoundItem(id: "ocean", name: "파도소리", icon: "water.waves", fileName: "ocean.wav", category: .nature),
        SoundItem(id: "birds", name: "새소리", icon: "bird.fill", fileName: "birds.wav", category: .nature),
        // 생활
        SoundItem(id: "heartbeat", name: "심장박동", icon: "heart.fill", fileName: "heartbeat.wav", category: .life),
        SoundItem(id: "fan", name: "선풍기", icon: "fan.fill", fileName: "fan.wav", category: .life),
        SoundItem(id: "shushing", name: "쉬 소리", icon: "mouth.fill", fileName: "shushing.wav", category: .life),
        // 음악
        SoundItem(id: "lullaby", name: "자장가", icon: "moon.stars.fill", fileName: "lullaby.wav", category: .music),
        SoundItem(id: "music_box", name: "오르골", icon: "music.note.list", fileName: "music_box.wav", category: .music),
    ]

    static func byCategory() -> [(SoundItem.SoundCategory, [SoundItem])] {
        SoundCategory.allCases.compactMap { cat in
            let items = all.filter { $0.category == cat }
            return items.isEmpty ? nil : (cat, items)
        }
    }
}

import AVFoundation

// MARK: - CryAnalysisService
// 울음 분석 서비스. 마이크 권한 관리, 세션 조율, 스텁 분석 제공.
// AVAudioPCMBuffer는 non-Sendable이므로 실제 분석은 [Float] 배열로 수신 (TODO v2.7).

@MainActor
final class CryAnalysisService {

    // MARK: - Error

    enum ServiceError: Error {
        case permissionDenied
        case sessionConfigurationFailed
        case notAvailable
    }

    // MARK: - Constants

    static let recordingDuration: TimeInterval = 5.0

    // MARK: - Session State

    private var previousCategory: AVAudioSession.Category?
    private var previousMode: AVAudioSession.Mode?

    // MARK: - Permission

    func permissionStatus() -> AVAudioApplication.recordPermission {
        AVAudioApplication.shared.recordPermission
    }

    func requestPermission() async -> Bool {
        await withCheckedContinuation { cont in
            AVAudioApplication.requestRecordPermission { granted in
                cont.resume(returning: granted)
            }
        }
    }

    // MARK: - Session Coordination

    func configureForRecording() throws {
        // CR-001: SoundPlayerService가 재생 중이면 먼저 정지 (백색소음/자장가 세션 충돌 방지)
        SoundPlayerService.shared.stop()

        let session = AVAudioSession.sharedInstance()
        previousCategory = session.category
        previousMode = session.mode
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothHFP])
            try session.setActive(true)
        } catch {
            throw ServiceError.sessionConfigurationFailed
        }
    }

    func restoreAfterRecording() {
        let session = AVAudioSession.sharedInstance()
        if let previousCategory {
            try? session.setCategory(previousCategory, mode: previousMode ?? .default)
        }
        try? session.setActive(false, options: [.notifyOthersOnDeactivation])
        previousCategory = nil
        previousMode = nil
    }

    // MARK: - Stub Analysis

    /// 스텁 구현. 모델 출시 전 App Review 안전용 고정 확률 반환.
    /// 실제 분석은 FeatureFlags.cryAnalysisEnabled 활성 시 v2.7에서 추가 예정.
    /// - Warning: 랜덤값 사용 금지 — 동일 입력에 동일 출력 보장.
    func analyzeStub(babyId: String) -> CryRecord {
        let equalProbability = 1.0 / Double(CryLabel.allCases.count)
        let probabilities: [String: Double] = Dictionary(
            uniqueKeysWithValues: CryLabel.allCases.map { ($0.rawValue, equalProbability) }
        )
        return CryRecord(
            babyId: babyId,
            durationSeconds: Self.recordingDuration,
            probabilities: probabilities,
            topLabel: nil,
            isStub: true
        )
    }

    // MARK: - Real Analysis (TODO v2.7)

    // func analyze(audioSamples: [Float], babyId: String) async throws -> CryRecord {
    //     // TODO: v2.7 - Load CreateML .mlmodel and run SNClassifySoundRequest
    //     // [Float] not AVAudioPCMBuffer (Sendable requirement).
    //     throw ServiceError.notAvailable
    // }
}

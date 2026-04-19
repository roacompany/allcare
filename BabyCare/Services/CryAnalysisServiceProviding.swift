import AVFoundation

/// CryAnalysisViewModel 이 의존하는 서비스 인터페이스.
/// 단위 테스트 시 Mock 주입을 위해 protocol로 분리.
@MainActor
protocol CryAnalysisServiceProviding {
    func permissionStatus() -> AVAudioApplication.recordPermission
    func requestPermission() async -> Bool
    func configureForRecording() throws
    func restoreAfterRecording()
    func analyzeStub(babyId: String) -> CryRecord
}

extension CryAnalysisService: CryAnalysisServiceProviding {}

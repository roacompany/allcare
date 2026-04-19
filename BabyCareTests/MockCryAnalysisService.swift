import AVFoundation
import Foundation
@testable import BabyCare

/// CryAnalysisViewModel phase 전이 테스트용 Mock.
/// 권한 상태 / 세션 설정 결과 / 분석 출력을 stub로 제어.
@MainActor
final class MockCryAnalysisService: CryAnalysisServiceProviding {
    var stubPermissionStatus: AVAudioApplication.recordPermission = .granted
    var stubRequestResult: Bool = true
    var configureThrows: Error?
    var stubAnalyzeRecord: CryRecord?

    private(set) var configureCalled = 0
    private(set) var restoreCalled = 0
    private(set) var requestCalled = 0

    func permissionStatus() -> AVAudioApplication.recordPermission {
        stubPermissionStatus
    }

    func requestPermission() async -> Bool {
        requestCalled += 1
        return stubRequestResult
    }

    func configureForRecording() throws {
        configureCalled += 1
        if let err = configureThrows { throw err }
    }

    func restoreAfterRecording() {
        restoreCalled += 1
    }

    func analyzeStub(babyId: String) -> CryRecord {
        stubAnalyzeRecord ?? CryRecord(
            babyId: babyId,
            durationSeconds: 5,
            probabilities: ["hungry": 1.0],
            topLabel: nil,
            isStub: true
        )
    }
}

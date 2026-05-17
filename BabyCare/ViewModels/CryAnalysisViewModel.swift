import Foundation
import Observation

// MARK: - CryAnalysisViewModel
// 울음 분석 화면의 상태 머신. 마이크 권한 → 녹음 → 분석 → 결과 흐름을 관리.
// Firestore 저장은 View 레이어에서 dataUserId를 주입받아 처리 (authVM 직접 참조 금지).

@MainActor
@Observable
final class CryAnalysisViewModel {

    // MARK: - Phase

    enum Phase: Equatable {
        case idle
        case permissionRequired
        case permissionDenied
        case recording(progress: Double)
        case analyzing
        case result(CryRecord)
        case error(String)

        static func == (lhs: Phase, rhs: Phase) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle): return true
            case (.permissionRequired, .permissionRequired): return true
            case (.permissionDenied, .permissionDenied): return true
            case (.recording(let a), .recording(let b)): return a == b
            case (.analyzing, .analyzing): return true
            case (.result(let a), .result(let b)): return a.id == b.id
            case (.error(let a), .error(let b)): return a == b
            default: return false
            }
        }
    }

    // MARK: - State

    var phase: Phase = .idle
    var history: [CryRecord] = []

    // MARK: - Dependencies

    private let service: CryAnalysisServiceProviding
    private let firestore: CryFirestoreProviding

    init(
        service: CryAnalysisServiceProviding = CryAnalysisService(),
        firestore: CryFirestoreProviding = FirestoreService.shared
    ) {
        self.service = service
        self.firestore = firestore
    }

    // MARK: - Recording Flow

    func start(babyId: String) async {
        // CR-003: 빈 babyId 가드 — orphan Firestore 문서 방지
        guard !babyId.isEmpty else {
            phase = .error("아기를 먼저 선택해주세요")
            return
        }

        // 1. 마이크 권한 확인
        switch service.permissionStatus() {
        case .denied:
            phase = .permissionDenied
            return
        case .undetermined:
            phase = .permissionRequired
            let granted = await service.requestPermission()
            if !granted {
                phase = .permissionDenied
                return
            }
        case .granted:
            break
        @unknown default:
            phase = .error("권한 상태 확인 실패")
            return
        }

        // 2. 오디오 세션 설정
        do {
            try service.configureForRecording()
        } catch {
            phase = .error("오디오 세션 설정 실패")
            return
        }

        // 3. 녹음 시뮬레이션 (5초, 20단계 진행률)
        // CR-002: Task 취소 시 세션 복원 보장
        let duration = CryAnalysisService.recordingDuration
        let steps = 20
        let stepInterval = UInt64((duration / Double(steps)) * 1_000_000_000)

        do {
            for step in 1...steps {
                phase = .recording(progress: Double(step) / Double(steps))
                try await Task.sleep(nanoseconds: stepInterval)
            }
        } catch {
            // 취소되면 세션 복원 후 idle 로 리셋
            service.restoreAfterRecording()
            phase = .idle
            return
        }

        // 4. 분석 (스텁)
        phase = .analyzing
        do {
            try await Task.sleep(nanoseconds: 300_000_000) // UX 딜레이
        } catch {
            service.restoreAfterRecording()
            phase = .idle
            return
        }
        let record = service.analyzeStub(babyId: babyId)

        // 5. 오디오 세션 복원
        service.restoreAfterRecording()

        phase = .result(record)
    }

    func cancel() {
        service.restoreAfterRecording()
        phase = .idle
    }

    // MARK: - Firestore Save

    /// CryRecord를 Firestore에 저장.
    /// dataUserId는 View에서 babyVM.dataUserId(currentUserId:) 를 통해 주입.
    func save(babyId: String, dataUserId: String, record: CryRecord) async throws {
        try await firestore.saveCryRecord(record, userId: dataUserId, babyId: babyId)
    }

    // MARK: - History

    func loadHistory(babyId: String, dataUserId: String) async throws {
        history = try await firestore.fetchRecentCryRecords(userId: dataUserId, babyId: babyId, limit: 20)
    }
}

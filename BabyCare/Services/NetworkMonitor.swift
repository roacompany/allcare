import Foundation
import Network

/// 네트워크 연결 상태 모니터링 서비스.
/// Firestore는 자체적으로 오프라인 캐시를 지원하므로,
/// 이 모니터는 사용자에게 연결 상태만 표시하는 용도.
@MainActor @Observable
final class NetworkMonitor {
    static let shared = NetworkMonitor()

    var isConnected = true
    var connectionType: ConnectionType = .unknown

    enum ConnectionType {
        case wifi, cellular, wired, unknown
    }

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")

    private init() {
        startMonitoring()
    }

    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let wasConnected = self.isConnected
                self.isConnected = path.status == .satisfied

                if path.usesInterfaceType(.wifi) {
                    self.connectionType = .wifi
                } else if path.usesInterfaceType(.cellular) {
                    self.connectionType = .cellular
                } else if path.usesInterfaceType(.wiredEthernet) {
                    self.connectionType = .wired
                } else {
                    self.connectionType = .unknown
                }

                // 오프라인 → 온라인 전환 시 대기 중인 작업 자동 플러시
                if !wasConnected && self.isConnected {
                    Task {
                        await OfflineQueue.shared.flush()
                    }
                }
            }
        }
        monitor.start(queue: queue)
    }
}

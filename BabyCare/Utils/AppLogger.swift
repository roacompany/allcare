import Foundation
import OSLog

/// 카테고리별 `os.Logger` 단일 진입점.
///
/// - 모든 카테고리가 같은 subsystem 사용 → Console.app / Instruments 에서 일괄 필터 가능.
/// - `print()` 금지 — 모든 진단은 AppLogger 경유 (PII 자동 마스킹, log level / category 활용).
/// - 신규 카테고리 추가 시 정렬 유지.
enum AppLogger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.roacompany.allcare"

    static let admin        = Logger(subsystem: subsystem, category: "Admin")
    static let analysis     = Logger(subsystem: subsystem, category: "Analysis")
    static let analytics    = Logger(subsystem: subsystem, category: "Analytics")
    static let auth         = Logger(subsystem: subsystem, category: "Auth")
    static let badge        = Logger(subsystem: subsystem, category: "Badge")
    static let calendar     = Logger(subsystem: subsystem, category: "Calendar")
    static let catalog      = Logger(subsystem: subsystem, category: "Catalog")
    static let firestore    = Logger(subsystem: subsystem, category: "Firestore")
    static let highlight    = Logger(subsystem: subsystem, category: "Highlight")
    static let liveActivity = Logger(subsystem: subsystem, category: "LiveActivity")
    static let ml           = Logger(subsystem: subsystem, category: "ML")
    static let pregnancy    = Logger(subsystem: subsystem, category: "Pregnancy")
    static let push         = Logger(subsystem: subsystem, category: "Push")
    static let sound        = Logger(subsystem: subsystem, category: "Sound")
    static let storage      = Logger(subsystem: subsystem, category: "Storage")
    static let todo         = Logger(subsystem: subsystem, category: "Todo")
}

/// non-fatal silent error 진단용 helper.
///
/// 정책:
/// - `try? await` / empty catch 패턴이 의도적으로 에러를 흘려보낼 때, 진단 로그만 남김.
/// - 사용자에게 errorMessage 노출하는 분기에는 사용 금지 (이중 표시 방지).
/// - 향후 Crashlytics non-fatal 연동 시 단일 후크 포인트.
@inlinable
func logSilent(_ message: String, error: Error? = nil, logger: Logger) {
    if let error {
        logger.warning("\(message, privacy: .public): \(error.localizedDescription, privacy: .public)")
    } else {
        logger.warning("\(message, privacy: .public)")
    }
}

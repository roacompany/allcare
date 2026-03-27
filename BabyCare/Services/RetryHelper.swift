import Foundation

enum RetryHelper {
    /// Exponential backoff retry with max 3 attempts
    /// - delay: 1s, 2s, 4s
    @MainActor
    static func withRetry<T>(
        maxAttempts: Int = 3,
        initialDelay: TimeInterval = 1.0,
        operation: () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        for attempt in 0..<maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error
                if attempt < maxAttempts - 1 {
                    let delay = initialDelay * pow(2.0, Double(attempt))
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        throw lastError!
    }

    /// Fire-and-forget with retry (for non-critical operations)
    @MainActor
    static func retryQuietly(
        maxAttempts: Int = 2,
        operation: () async throws -> Void
    ) async {
        for attempt in 0..<maxAttempts {
            do {
                try await operation()
                return
            } catch {
                if attempt < maxAttempts - 1 {
                    try? await Task.sleep(nanoseconds: UInt64(1_000_000_000))
                }
            }
        }
    }
}

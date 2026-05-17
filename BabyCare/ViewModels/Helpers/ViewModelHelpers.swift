import Foundation

// MARK: - LoadingStateful (withLoading)

/// `isLoading` 토글 보일러를 헬퍼로 추상화. ViewModel 이 채택 후 `withLoading { ... }` 사용.
///
/// 정책:
/// - `defer { isLoading = false }` 누락 invariant 보장 — early-return / throw / cancellation 모두 안전.
/// - 중첩 호출은 외부 wrapper 만 effective (안쪽에서 다시 true→false 토글되어도 손해 없음).
@MainActor
protocol LoadingStateful: AnyObject {
    var isLoading: Bool { get set }
}

extension LoadingStateful {
    /// async 블록을 실행하는 동안 `isLoading = true`, 종료 시 자동 false.
    /// throws 도 rethrows 로 전파 — 상위가 do/catch 처리.
    func withLoading<T>(_ op: () async throws -> T) async rethrows -> T {
        isLoading = true
        defer { isLoading = false }
        return try await op()
    }
}

// MARK: - OptimisticReplaceable (optimisticReplace)

/// Optimistic update + 자동 rollback 패턴 추상화.
///
/// 정책:
/// - save 성공 시 nil 반환, 실패 시 error 반환 (호출자가 errorMessage 매핑).
/// - 배열의 같은 `id` 원소를 찾아 교체. firstIndex 검색 + rollback 모두 helper 내부.
/// - LoadingStateful 와 직교 — 두 protocol 모두 채택 가능.
@MainActor
protocol OptimisticReplaceable: AnyObject {}

extension OptimisticReplaceable {
    /// 배열의 같은 id 원소를 `updated` 로 교체 → save → 실패 시 `original` 로 rollback.
    /// 항목을 찾지 못하면 save 만 수행하고 결과 반환.
    @discardableResult
    func optimisticReplace<Item: Identifiable>(
        in items: ReferenceWritableKeyPath<Self, [Item]>,
        original: Item,
        with updated: Item,
        save: () async throws -> Void
    ) async -> Error? where Item.ID: Equatable {
        let idx = self[keyPath: items].firstIndex { $0.id == original.id }
        if let idx { self[keyPath: items][idx] = updated }
        do {
            try await save()
            return nil
        } catch {
            if let idx { self[keyPath: items][idx] = original }
            return error
        }
    }
}

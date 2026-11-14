import FirebaseFirestore
import Foundation

/// 서버가 받아들였는지 확인하는 쓰기에서, 시간 안에 서버 답이 없을 때.
enum ServerConfirmationError: Error, Equatable {
    case timedOut
}

extension FirestoreService {
    /// 서버 확인 쓰기의 기다리는 시간.
    static let serverConfirmationTimeout: TimeInterval = 15

    /// RED 판: 고치기 전 동작 그대로 — 서버 답을 기다리지 않는다(거부를 삼킨다).
    static func awaitServerConfirmation(
        timeout: TimeInterval = serverConfirmationTimeout,
        _ write: (@escaping @Sendable (Error?) -> Void) -> Void
    ) async throws {
        write { _ in }
    }

    /// 객체를 저장하고 서버가 받아들일 때까지 기다린다(거부·시간 초과는 던진다).
    func setDataConfirmed<T: Encodable>(_ value: T, at ref: DocumentReference) async throws {
        let data = try Firestore.Encoder().encode(value)
        try await Self.awaitServerConfirmation { done in
            ref.setData(data, completion: done)
        }
    }

    /// 칸 몇 개를 고치고 서버가 받아들일 때까지 기다린다(거부·시간 초과는 던진다).
    func updateDataConfirmed(_ fields: [String: Any], at ref: DocumentReference) async throws {
        try await Self.awaitServerConfirmation { done in
            ref.updateData(fields, completion: done)
        }
    }
}

import FirebaseFirestore
import Foundation

/// 서버가 받아들였는지 확인하는 쓰기에서, 시간 안에 서버 답이 없을 때.
enum ServerConfirmationError: Error, Equatable {
    case timedOut
}

extension FirestoreService {
    /// 서버 확인 쓰기의 기다리는 시간. 오프라인이면 Firestore 는 서버 답(completion)을 부르지 않아 끝없이 기다리게 된다.
    static let serverConfirmationTimeout: TimeInterval = 15

    /// 서버 답을 기다린다 — 받아들이면 돌아오고, 거부하면 그 에러를 던지고, 시간 안에 답이 없으면 `.timedOut`.
    /// `write` 는 받은 끝 알림을 Firestore 쓰기의 completion 으로 넘긴다. 시간 초과 뒤 늦은 답은 버린다(두 번 끝내지 않는다).
    ///
    /// ⚠️ 왜 따로 있나: `DocumentReference.setData(from:)`(Codable 판)는 Firebase 11.9 에서 **동기 함수**다
    /// (SDK `DocumentReference+WriteEncodable.swift`) — `try await` 를 붙여도 서버를 기다리지 않고 규칙 거부도 던지지 않는다.
    /// 컴파일러 경고 「no 'async' operations occur within 'await' expression」가 그 표시다.
    /// 규칙이 거부할 수 있고 그 결과를 사람에게 알려야 하는 쓰기(초대·공유)는 이 길로 쓴다.
    static func awaitServerConfirmation(
        timeout: TimeInterval = serverConfirmationTimeout,
        _ write: (@escaping @Sendable (Error?) -> Void) -> Void
    ) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let gate = FinishOnce(continuation)
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                gate.finish(ServerConfirmationError.timedOut)
            }
            write { error in gate.finish(error) }
        }
    }

    /// 새로 만드는 쓰기 — 서버 답을 기다리되, 시간 안에 답이 없으면 `retract`(방금 쓴 것을 거두는 지우기)를 줄 세우고 `.timedOut`.
    /// Firestore 는 답이 늦어도 쓰기를 기기에 남겼다가 망이 돌아오면 보낸다 → 「실패」라고 알린 초대·공유가 나중에 생겨 버린다.
    /// 규칙 거부는 SDK 가 기기에서도 지우므로 거두지 않는다(거부를 그대로 던진다).
    static func confirmOrRetract(
        timeout: TimeInterval = serverConfirmationTimeout,
        _ write: (@escaping @Sendable (Error?) -> Void) -> Void,
        retract: () -> Void
    ) async throws {
        do {
            try await awaitServerConfirmation(timeout: timeout, write)
        } catch ServerConfirmationError.timedOut {
            retract()
            throw ServerConfirmationError.timedOut
        }
    }

    /// 없던 문서를 새로 만들고 서버 확인을 기다린다 — 시간 안에 답이 없으면 거둔다(지우기를 기기 쓰기 줄에 세운다).
    /// 그러면 망이 돌아왔을 때 「쓰기 → 지우기」 순서로 가서, 화면이 말한 「실패」와 끝 상태가 같다.
    /// ⚠️ 없던 문서에만 — 있던 문서를 덮어쓰는 데 쓰면 시간 초과 때 있던 것까지 지운다(레거시 이전은 `setDataConfirmed`).
    func createConfirmed<T: Encodable>(_ value: T, at ref: DocumentReference) async throws {
        let data = try Firestore.Encoder().encode(value)
        try await Self.confirmOrRetract({ done in
            ref.setData(data, completion: done)
        }, retract: {
            ref.delete(completion: nil)
        })
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

/// 끝 알림을 한 번만 — CheckedContinuation 을 두 번 끝내면 앱이 꺼진다.
private final class FinishOnce: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Error>?

    init(_ continuation: CheckedContinuation<Void, Error>) {
        self.continuation = continuation
    }

    func finish(_ error: Error?) {
        lock.lock()
        let pending = continuation
        continuation = nil
        lock.unlock()
        guard let pending else { return }
        if let error {
            pending.resume(throwing: error)
        } else {
            pending.resume()
        }
    }
}

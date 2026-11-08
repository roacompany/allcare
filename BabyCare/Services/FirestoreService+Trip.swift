import Foundation
import FirebaseFirestore

/// 여행 저장소 — VM 이 의존하는 좁은 면. 경로 = users/{소유자}/babies/{아기}/trips/{tripId}(여행 하나 = 문서 하나).
/// 아기 아래 한 단계라 지금 firestore.rules 가 소유자·공유 보호자 둘 다 허용한다(규칙 변경 없음).
///
/// 🔴 만든 뒤에는 **칸 하나씩만** 쓴다(bookings.<id> · taskStates.<taskId> · moves.<id> · 여행 정보 칸).
///    문서를 통째로 다시 쓰면 옛 사본이 새 예약을 지우고, 두 보호자 중 늦게 저장한 쪽이 상대 것을 지운다(2026-11-04 검토).
///    쓰기는 기존 관례대로 기다리지 않는다(오프라인이면 큐에 쌓였다가 연결되면 올라간다 — 여행지 로밍).
protocol TripFirestoreProviding: Sendable {
    func fetchTrips(userId: String, babyId: String) async throws -> [Trip]
    /// 새 여행 한 번만 통째로 쓴다.
    func createTrip(_ trip: Trip, userId: String) async throws
    func deleteTrip(_ tripId: String, userId: String, babyId: String) async throws
    /// 열린 여행을 늘 최신으로 — 캐시에서 바로 한 번, 그 뒤 바뀔 때마다. nil = 지워짐.
    func tripUpdates(userId: String, babyId: String, tripId: String) -> AsyncStream<Trip?>
    func saveBooking(_ booking: TripBooking, tripId: String, babyId: String, userId: String) async throws
    func deleteBooking(_ bookingId: String, tripId: String, babyId: String, userId: String) async throws
    func saveTaskState(_ state: TripTaskState, tripId: String, babyId: String, userId: String) async throws
    func saveMove(_ move: TripMove, tripId: String, babyId: String, userId: String) async throws
    func deleteMove(_ moveId: String, tripId: String, babyId: String, userId: String) async throws
    func updateTripInfo(city: String, startDay: String, endDay: String, tripId: String, babyId: String, userId: String) async throws
}

/// 여행 할 일·하루 일정에 쓰는 아기 기록 — 이미 있는 조회를 그대로 쓴다.
protocol TripChildDataProviding: Sendable {
    func fetchGrowthRecords(userId: String, babyId: String) async throws -> [GrowthRecord]
    func fetchActivities(userId: String, babyId: String, from startDate: Date, to endDate: Date) async throws -> [Activity]
}

extension FirestoreService {

    private func tripCollection(_ userId: String, babyId: String) -> CollectionReference {
        db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.babies)
            .document(babyId)
            .collection(FirestoreCollections.trips)
    }

    private func tripDocument(_ userId: String, babyId: String, tripId: String) -> DocumentReference {
        tripCollection(userId, babyId: babyId).document(tripId)
    }

    func fetchTrips(userId: String, babyId: String) async throws -> [Trip] {
        let snapshot = try await tripCollection(userId, babyId: babyId)
            .order(by: "startDay", descending: false)
            .getDocuments()
        return decodeDocuments(snapshot.documents, as: Trip.self)
    }

    func createTrip(_ trip: Trip, userId: String) async throws {
        try tripDocument(userId, babyId: trip.babyId, tripId: trip.id).setData(from: trip)
    }

    func deleteTrip(_ tripId: String, userId: String, babyId: String) async throws {
        try await tripDocument(userId, babyId: babyId, tripId: tripId).delete()
    }

    func tripUpdates(userId: String, babyId: String, tripId: String) -> AsyncStream<Trip?> {
        let ref = tripDocument(userId, babyId: babyId, tripId: tripId)
        return AsyncStream { continuation in
            let registration = ref.addSnapshotListener { snapshot, error in
                if let error {
                    logSilent("여행 실시간 읽기 실패", error: error, logger: AppLogger.travel)
                    return
                }
                guard let snapshot else { return }
                guard snapshot.exists else {
                    continuation.yield(nil)
                    return
                }
                do {
                    continuation.yield(try snapshot.data(as: Trip.self))
                } catch {
                    logSilent("여행 문서 읽기 실패(이 문서는 건너뜀)", error: error, logger: AppLogger.travel)
                }
            }
            let box = TripListenerBox(registration)
            continuation.onTermination = { _ in box.remove() }
        }
    }

    func saveBooking(_ booking: TripBooking, tripId: String, babyId: String, userId: String) async throws {
        let value = try Firestore.Encoder().encode(booking)
        writeFields([FieldPath(["bookings", booking.id]): value], userId: userId, babyId: babyId, tripId: tripId)
    }

    func deleteBooking(_ bookingId: String, tripId: String, babyId: String, userId: String) async throws {
        writeFields([FieldPath(["bookings", bookingId]): FieldValue.delete()], userId: userId, babyId: babyId, tripId: tripId)
    }

    func saveTaskState(_ state: TripTaskState, tripId: String, babyId: String, userId: String) async throws {
        let value = try Firestore.Encoder().encode(state)
        writeFields([FieldPath(["taskStates", state.taskId]): value], userId: userId, babyId: babyId, tripId: tripId)
    }

    func saveMove(_ move: TripMove, tripId: String, babyId: String, userId: String) async throws {
        let value = try Firestore.Encoder().encode(move)
        writeFields([FieldPath(["moves", move.id]): value], userId: userId, babyId: babyId, tripId: tripId)
    }

    func deleteMove(_ moveId: String, tripId: String, babyId: String, userId: String) async throws {
        writeFields([FieldPath(["moves", moveId]): FieldValue.delete()], userId: userId, babyId: babyId, tripId: tripId)
    }

    func updateTripInfo(city: String, startDay: String, endDay: String, tripId: String, babyId: String, userId: String) async throws {
        writeFields([FieldPath(["city"]): city, FieldPath(["startDay"]): startDay, FieldPath(["endDay"]): endDay],
                    userId: userId, babyId: babyId, tripId: tripId)
    }

    /// 칸만 쓴다 + updatedAt. 서버 시각(serverTimestamp)은 쓰지 않는다 — 올라가기 전 로컬 스냅샷에서 비어 문서가 안 읽힌다.
    private func writeFields(_ fields: [FieldPath: Any], userId: String, babyId: String, tripId: String) {
        var all: [AnyHashable: Any] = [:]
        for (key, value) in fields { all[key] = value }
        all[FieldPath(["updatedAt"])] = Timestamp(date: Date())
        tripDocument(userId, babyId: babyId, tripId: tripId).updateData(all) { error in
            if let error { logSilent("여행 칸 쓰기 실패", error: error, logger: AppLogger.travel) }
        }
    }
}

extension FirestoreService: TripFirestoreProviding, TripChildDataProviding {}

/// 스냅샷 리스너 해제 — onTermination(@Sendable)에서 부르려고 상자에 넣는다.
private final class TripListenerBox: @unchecked Sendable {
    private let registration: ListenerRegistration

    init(_ registration: ListenerRegistration) {
        self.registration = registration
    }

    func remove() {
        registration.remove()
    }
}

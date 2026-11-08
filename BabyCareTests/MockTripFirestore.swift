import Foundation
@testable import BabyCare

/// 여행 저장소 Mock — in-memory (소유자/아기)별 스토어 · 칸 단위 쓰기 · 실시간 스트림 · 호출 카운터 · 에러 주입.
/// Swift 6 Sendable: 단일 쓰레드 테스트 전용이므로 `@unchecked Sendable`.
final class MockTripFirestore: TripFirestoreProviding, @unchecked Sendable {
    private var store: [String: [Trip]] = [:]
    private var listeners: [String: [AsyncStream<Trip?>.Continuation]] = [:]

    var fetchCount = 0
    var deleteCount = 0
    var writeCount = 0
    var capturedUserIds: [String] = []
    var created: [(trip: Trip, userId: String)] = []
    var errorToThrow: Error?

    private func key(_ userId: String, _ babyId: String) -> String { "\(userId)/\(babyId)" }

    func seed(_ trips: [Trip], userId: String, babyId: String) {
        store[key(userId, babyId)] = trips
    }

    /// 저장소에 지금 들어 있는 여행(테스트가 「무엇이 남았나」를 본다).
    func stored(userId: String, babyId: String, tripId: String) -> Trip? {
        store[key(userId, babyId)]?.first { $0.id == tripId }
    }

    /// 다른 보호자 폰에서 바뀐 것처럼 — 저장소를 바꾸고 열린 화면에 흘려보낸다.
    func push(_ trip: Trip, userId: String) {
        upsert(trip, userId: userId)
        notify(userId: userId, babyId: trip.babyId, tripId: trip.id)
    }

    func fetchTrips(userId: String, babyId: String) async throws -> [Trip] {
        fetchCount += 1
        capturedUserIds.append(userId)
        if let e = errorToThrow { throw e }
        return (store[key(userId, babyId)] ?? []).sorted { $0.startDay < $1.startDay }
    }

    func createTrip(_ trip: Trip, userId: String) async throws {
        capturedUserIds.append(userId)
        if let e = errorToThrow { throw e }
        created.append((trip, userId))
        upsert(trip, userId: userId)
    }

    func deleteTrip(_ tripId: String, userId: String, babyId: String) async throws {
        deleteCount += 1
        capturedUserIds.append(userId)
        if let e = errorToThrow { throw e }
        store[key(userId, babyId)] = (store[key(userId, babyId)] ?? []).filter { $0.id != tripId }
        notify(userId: userId, babyId: babyId, tripId: tripId)
    }

    func tripUpdates(userId: String, babyId: String, tripId: String) -> AsyncStream<Trip?> {
        AsyncStream { continuation in
            listeners["\(key(userId, babyId))/\(tripId)", default: []].append(continuation)
            continuation.yield(stored(userId: userId, babyId: babyId, tripId: tripId))
        }
    }

    func saveBooking(_ booking: TripBooking, tripId: String, babyId: String, userId: String) async throws {
        try mutate(userId, babyId, tripId) { trip in
            if let i = trip.bookings.firstIndex(where: { $0.id == booking.id }) { trip.bookings[i] = booking } else { trip.bookings.append(booking) }
        }
    }

    func deleteBooking(_ bookingId: String, tripId: String, babyId: String, userId: String) async throws {
        try mutate(userId, babyId, tripId) { $0.bookings.removeAll { $0.id == bookingId } }
    }

    func saveTaskState(_ state: TripTaskState, tripId: String, babyId: String, userId: String) async throws {
        try mutate(userId, babyId, tripId) { trip in
            if let i = trip.taskStates.firstIndex(where: { $0.taskId == state.taskId }) { trip.taskStates[i] = state } else { trip.taskStates.append(state) }
        }
    }

    func saveMove(_ move: TripMove, tripId: String, babyId: String, userId: String) async throws {
        try mutate(userId, babyId, tripId) { trip in
            if let i = trip.moves.firstIndex(where: { $0.id == move.id }) { trip.moves[i] = move } else { trip.moves.append(move) }
        }
    }

    func deleteMove(_ moveId: String, tripId: String, babyId: String, userId: String) async throws {
        try mutate(userId, babyId, tripId) { $0.moves.removeAll { $0.id == moveId } }
    }

    func updateTripInfo(city: String, startDay: String, endDay: String, tripId: String, babyId: String, userId: String) async throws {
        try mutate(userId, babyId, tripId) { trip in
            trip.city = city
            trip.startDay = startDay
            trip.endDay = endDay
        }
    }

    // MARK: - 내부

    /// 실제 updateData 처럼 — 저장소의 **지금** 문서에 칸만 바꾼다(없는 문서면 아무 일도 없다).
    private func mutate(_ userId: String, _ babyId: String, _ tripId: String, _ change: (inout Trip) -> Void) throws {
        writeCount += 1
        capturedUserIds.append(userId)
        if let e = errorToThrow { throw e }
        guard var trip = stored(userId: userId, babyId: babyId, tripId: tripId) else { return }
        change(&trip)
        upsert(trip, userId: userId)
        notify(userId: userId, babyId: babyId, tripId: tripId)
    }

    private func upsert(_ trip: Trip, userId: String) {
        var list = store[key(userId, trip.babyId)] ?? []
        if let i = list.firstIndex(where: { $0.id == trip.id }) { list[i] = trip } else { list.append(trip) }
        store[key(userId, trip.babyId)] = list
    }

    private func notify(userId: String, babyId: String, tripId: String) {
        let current = stored(userId: userId, babyId: babyId, tripId: tripId)
        for c in listeners["\(key(userId, babyId))/\(tripId)"] ?? [] { c.yield(current) }
    }
}

/// 아기 기록 Mock — 성장 기록·활동을 그대로 돌려주고 받은 인자를 남긴다.
final class MockTripChildData: TripChildDataProviding, @unchecked Sendable {
    var growth: [GrowthRecord] = []
    var activities: [Activity] = []
    var capturedUserIds: [String] = []
    var capturedFrom: Date?
    var capturedTo: Date?
    var errorToThrow: Error?

    func fetchGrowthRecords(userId: String, babyId: String) async throws -> [GrowthRecord] {
        capturedUserIds.append(userId)
        if let e = errorToThrow { throw e }
        return growth
    }

    func fetchActivities(userId: String, babyId: String, from startDate: Date, to endDate: Date) async throws -> [Activity] {
        capturedUserIds.append(userId)
        capturedFrom = startDate
        capturedTo = endDate
        if let e = errorToThrow { throw e }
        return activities
    }
}

/// 알림 Mock — 건 것·지운 것을 남긴다.
@MainActor
final class MockTripReminderScheduler: TripReminderScheduling {
    var replaced: [(tripId: String, reminders: [TripReminder])] = []
    var cancelled: [String] = []
    var cancelledKinds: [String] = []

    func replaceTripReminders(tripId: String, with reminders: [TripReminder]) async {
        replaced.append((tripId, reminders))
    }

    func cancelTripReminders(tripId: String) async {
        cancelled.append(tripId)
    }

    func cancelTripReminders(kindSuffix: String) async {
        cancelledKinds.append(kindSuffix)
    }
}

import Foundation

/// 여행 목록 — 설정 「여행 준비」와 홈 카드가 쓴다. 화면에 로컬 @State 로 둔다(AppState 에 넣지 않음).
@MainActor @Observable
final class TripListViewModel: LoadingStateful {
    var trips: [Trip] = []
    var isLoading = false
    var errorMessage: String?

    private let provider: TripFirestoreProviding
    private let now: () -> Date

    init(provider: TripFirestoreProviding = TripStore.live, now: @escaping () -> Date = Date.init) {
        self.provider = provider
        self.now = now
    }

    /// ownerUserId = `babyVM.dataUserId(currentUserId:)`. ⚠️ currentUserId 가 없으면 읽지 않는다 —
    /// dataUserId 는 로그아웃 뒤에도 공유 아기의 소유자 uid 를 돌려준다.
    func load(currentUserId: String?, ownerUserId: String?, babyId: String?) async {
        guard FeatureFlags.travelEnabled, let currentUserId, let babyId else {
            trips = []
            return
        }
        let owner = ownerUserId ?? currentUserId
        await withLoading {
            do {
                trips = try await provider.fetchTrips(userId: owner, babyId: babyId)
                errorMessage = nil
            } catch {
                AppLogger.travel.error("여행 불러오기 실패: \(error.localizedDescription, privacy: .public)")
                errorMessage = "여행을 불러오지 못했어요. 잠시 뒤 다시 열어 주세요."
            }
        }
    }

    /// 빈 여행을 만든다 — 예약·할 일은 사람이 넣는다(예시를 미리 넣지 않는다).
    func create(city: String, countryCode: String, startDay: String, endDay: String,
                currentUserId: String?, ownerUserId: String?, babyId: String?) async -> Trip? {
        guard let currentUserId, let babyId else { return nil }
        let stamp = now()
        let trip = Trip(babyId: babyId, countryCode: countryCode,
                        city: city.trimmingCharacters(in: .whitespacesAndNewlines),
                        startDay: startDay, endDay: endDay, createdBy: currentUserId,
                        createdAt: stamp, updatedAt: stamp)
        do {
            try await provider.createTrip(trip, userId: ownerUserId ?? currentUserId)
            trips.append(trip)
            trips.sort { $0.startDay < $1.startDay }
            errorMessage = nil
            return trip
        } catch {
            AppLogger.travel.error("여행 만들기 실패: \(error.localizedDescription, privacy: .public)")
            errorMessage = "여행을 만들지 못했어요. 다시 해 주세요."
            return nil
        }
    }

    /// 화면용 — 알림은 기기 알림 서비스로 지운다(화면이 알림 서비스를 직접 부르지 않게 · arch R1).
    func delete(_ trip: Trip, currentUserId: String?, ownerUserId: String?) async {
        await delete(trip, currentUserId: currentUserId, ownerUserId: ownerUserId, reminders: NotificationService.shared)
    }

    /// 사용자가 확인한 뒤에만 부른다. 그 여행의 마감 알림도 같이 지운다.
    func delete(_ trip: Trip, currentUserId: String?, ownerUserId: String?, reminders: TripReminderScheduling) async {
        guard let currentUserId else { return }
        do {
            try await provider.deleteTrip(trip.id, userId: ownerUserId ?? currentUserId, babyId: trip.babyId)
            trips.removeAll { $0.id == trip.id }
            await reminders.cancelTripReminders(tripId: trip.id)
            errorMessage = nil
        } catch {
            AppLogger.travel.error("여행 지우기 실패: \(error.localizedDescription, privacy: .public)")
            errorMessage = "여행을 지우지 못했어요. 다시 해 주세요."
        }
    }

    /// 홈 카드에 올릴 여행 — 아직 안 끝난(마지막 날 ≥ 오늘) 것 중 가장 이른 것.
    func nextTrip(today: Date, calendar: Calendar) -> Trip? {
        let key = Trip.dayKey(today, calendar: calendar)
        return trips.filter { $0.endDay >= key }.min { $0.startDay < $1.startDay }
    }
}

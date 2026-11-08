import Foundation

/// 여행 하나 — 할 일 · 일정 · 예약 · 규칙 네 칸.
/// 🔴 열린 동안 저장소를 지켜보고(observe) 늘 최신 문서를 그린다 · 고칠 때는 그 칸 하나만 쓴다 — 받은 사본을 통째로 저장하지 않는다
///    (옛 사본이 새 예약을 지우고, 두 보호자 중 늦게 저장한 쪽이 상대 체크를 지우던 것 · 2026-11-04 검토).
@MainActor @Observable
final class TripDetailViewModel {
    private(set) var trip: Trip { didSet { recalculateItinerary() } }
    private(set) var rhythm: BabyRhythm? { didSet { recalculateItinerary() } }
    /// 일정표 — 여행 문서 · 아기 리듬 · 지도 답이 바뀔 때만 다시 계산한다. 화면은 값만 읽는다.
    private(set) var itinerary: Itinerary
    private(set) var child: TripChildContext
    /// 아이 칸 「키 70.5cm, 10.3 측정」 — 키·체중은 따로 잰 날이 다를 수 있다.
    private(set) var latestHeight: TripGrowthReading?
    private(set) var latestWeight: TripGrowthReading?
    /// 이 폰의 알림 켜고 끄기(준비 칸 할 일 아래).
    private(set) var reminderOptions: TripReminderOptions
    /// 아기 기록을 못 읽었으면 참 — 「기록이 없다」와 구분해 말한다.
    private(set) var childLoadFailed = false
    /// 다른 보호자가 여행을 지웠으면 참.
    private(set) var isDeleted = false
    var errorMessage: String?
    /// 항공편 예약 id → 인천공항 운항 정보(오늘 편) · 「그날 보여요」(다른 날 편).
    var flightLive: [String: FlightLiveState] = [:]
    /// 이동 시간 — 지도에 넘긴 두 이름 → 답(같은 두 곳은 한 번만 묻는다 · 못 찾은 곳은 다시 묻지 않는다).
    var routes: [TripRouteKey: TripRouteAnswer] = [:] { didSet { recalculateItinerary() } }
    @ObservationIgnored var routeTasks: [TripRouteKey: Task<RouteLookup, Never>] = [:]

    let calendar: Calendar
    private let ownerUserId: String
    private let currentUserId: String
    private let provider: TripFirestoreProviding
    private let childData: TripChildDataProviding
    private let reminders: TripReminderScheduling
    private let reminderPreferences: TripReminderPreferencesStoring
    let flightStatus: FlightStatusProviding
    let routeTime: RouteTimeProviding
    let flightSchedule: FlightScheduleProviding
    /// Babycare AI로 추가(캡처 → 예약) — 글자 읽기 · 예약 뽑기 · 숙소 주소 찾기. 전부 폰 안(설계 §9).
    let captureText: CaptureTextReading
    let captureExtractor: CaptureExtracting
    let placeAddress: PlaceAddressLooking
    private let now: () -> Date
    /// 저장소에서 한 번이라도 받았나 — 받기 전엔 넘겨받은 사본이라 알림을 그걸로 다시 걸지 않는다.
    private var hasFreshTrip = false
    /// 알림 다시 걸기를 한 줄로 세운다(지우기·걸기가 서로 끼어들면 끝낸 일 알림이 남는다).
    private var replanTask: Task<Void, Never>?

    /// ownerUserId = 공유 아기면 소유자 uid, currentUserId = 체크한 사람으로 남길 uid.
    init(trip: Trip, ownerUserId: String, currentUserId: String, babyBirthDate: Date,
         provider: TripFirestoreProviding = TripStore.live,
         childData: TripChildDataProviding = TripStore.childData,
         reminders: TripReminderScheduling = NotificationService.shared,
         reminderPreferences: TripReminderPreferencesStoring? = nil,
         flightStatus: FlightStatusProviding? = nil,
         routeTime: RouteTimeProviding? = nil,
         flightSchedule: FlightScheduleProviding? = nil,
         captureText: CaptureTextReading? = nil,
         captureExtractor: CaptureExtracting? = nil,
         placeAddress: PlaceAddressLooking? = nil,
         now: @escaping () -> Date = Date.init,
         calendar: Calendar = .current) {
        self.trip = trip
        self.ownerUserId = ownerUserId
        self.currentUserId = currentUserId
        self.provider = provider
        self.childData = childData
        self.reminders = reminders
        self.flightStatus = flightStatus ?? IncheonFlightStatusService()
        self.routeTime = routeTime ?? TripStore.routeTime
        self.flightSchedule = flightSchedule ?? TripStore.flightSchedule
        self.captureText = captureText ?? VisionCaptureTextReader()
        self.captureExtractor = captureExtractor ?? BookingCaptureServices.standardExtractor()
        self.placeAddress = placeAddress ?? AppleMapsPlaceAddress()
        let preferences = reminderPreferences ?? TripReminderPreferences.shared
        self.reminderPreferences = preferences
        self.reminderOptions = preferences.options
        self.now = now
        self.calendar = calendar
        self.child = TripChildContext(birthDate: babyBirthDate, heightCm: nil, weightKg: nil, meat: .noSolids, hasSolids: false)
        self.itinerary = Itinerary(trip: trip, rhythm: nil, calendar: calendar)
    }

    /// 입력이 바뀌면 다시 계산한다 — 같으면 화면을 건드리지 않는다.
    private func recalculateItinerary() {
        let next = Itinerary(trip: trip, rhythm: rhythm, routes: routes, calendar: calendar)
        if next != itinerary { itinerary = next }
    }

    // MARK: - 읽기(계산)

    var today: Date { now() }

    /// 권장일 순 · 끝난 일은 뒤.
    var tasks: [TripTask] {
        TripTaskOrdering.ordered(rawTasks, states: trip.taskStates)
    }

    var days: [Date] { trip.days(calendar: calendar) }

    func state(for taskId: String) -> TripTaskState? {
        trip.taskStates.first { $0.taskId == taskId }
    }

    /// 이 여행에 걸리는 규칙 카드 — 할 일이 있는 규칙 + 일본이면 고기 든 이유식(기록을 안 한 집도 규칙은 보게) + 항공편이 있으면 기내 반입.
    var ruleCards: [TripRuleCard] {
        var keys: [TripRuleKey] = []
        for task in rawTasks where !keys.contains(task.key) { keys.append(task.key) }
        if trip.countryCode.uppercased() == "JP" && !keys.contains(.solidsQuarantine) {
            keys.append(.solidsQuarantine)
        }
        if trip.bookings.contains(where: { $0.kind == .flight }) && !keys.contains(.liquidsOnboard) {
            keys.append(.liquidsOnboard)
        }
        return keys.map(TripRuleCatalog.card)
    }

    /// 출발·도착 공항(편마다) — 정보가 있는 곳만 facility 가 있다.
    var airports: [(code: String, airline: String?, facility: AirportFacility?)] {
        var seen = Set<String>()
        var result: [(code: String, airline: String?, facility: AirportFacility?)] = []
        for f in trip.bookings where f.kind == .flight {
            for code in [f.fromAirport, f.toAirport].compactMap({ $0?.uppercased() }) where !code.isEmpty {
                let key = "\(code)-\(f.airline ?? "")"
                guard seen.insert(key).inserted else { continue }
                result.append((code, f.airline, AirportFacilityCatalog.facility(airport: code, airline: f.airline)))
            }
        }
        return result
    }

    private var rawTasks: [TripTask] {
        TripTaskEngine.tasks(trip: trip, child: child, now: now(), calendar: calendar)
    }

    // MARK: - 지켜보기

    /// 화면이 열려 있는 동안 저장소의 최신 문서를 받는다(캐시에서 바로 한 번, 그 뒤 바뀔 때마다 — 다른 보호자 것 포함).
    /// 화면의 `.task` 가 끝나면(닫히면) 스트림도 끝난다.
    func observe() async {
        for await latest in provider.tripUpdates(userId: ownerUserId, babyId: trip.babyId, tripId: trip.id) {
            guard let latest else {
                isDeleted = true
                await replan(cancelOnly: true)
                continue
            }
            isDeleted = false
            trip = latest
            hasFreshTrip = true
            await replan()
        }
    }

    // MARK: - 아기 기록

    /// 성장 기록(키·체중 각각 가장 최근 값)과 리듬 창의 활동을 읽는다. 활동 조회는 시작 시각만 물으므로 하루 앞부터.
    func loadChild() async {
        let window = BabyRhythmSummary.window(trip: trip, now: now(), calendar: calendar)
        let from = calendar.date(byAdding: .day, value: -1, to: window.start) ?? window.start
        do {
            let growth = try await childData.fetchGrowthRecords(userId: ownerUserId, babyId: trip.babyId)
            let activities = try await childData.fetchActivities(userId: ownerUserId, babyId: trip.babyId, from: from, to: window.end)
            let built = BabyRhythmSummary.build(activities: activities, window: window, calendar: calendar)
            let byDate = growth.sorted { $0.date > $1.date }
            latestHeight = byDate.first { $0.height != nil }.flatMap { r in r.height.map { TripGrowthReading(value: $0, measuredOn: r.date) } }
            latestWeight = byDate.first { $0.weight != nil }.flatMap { r in r.weight.map { TripGrowthReading(value: $0, measuredOn: r.date) } }
            rhythm = built.daysWithRecords > 0 ? built : nil
            child = TripChildContext(birthDate: child.birthDate,
                                     heightCm: byDate.first { $0.height != nil }?.height,
                                     weightKg: byDate.first { $0.weight != nil }?.weight,
                                     meat: built.meat, hasSolids: built.hasSolids)
            childLoadFailed = false
        } catch {
            logSilent("여행 — 아기 기록 읽기 실패(리듬 없이 보여 줌)", error: error, logger: AppLogger.travel)
            childLoadFailed = true
        }
        // 읽기가 지우기·닫기보다 늦게 끝나도 지운 여행의 알림을 다시 걸지 않는다(검토 11/5).
        if hasFreshTrip, !isDeleted, !Task.isCancelled { await replan() }
    }

    // MARK: - 고치기(칸 하나씩)

    /// 알림 켜고 끄기(준비 칸) — 이 폰에 남기고 바로 다시 건다.
    func setReminderOptions(_ options: TripReminderOptions) async {
        let before = reminderOptions
        reminderPreferences.options = options
        reminderOptions = options
        // 「이 폰에만」 설정 — 끈 종류는 열지 않은 다른 여행에서도 빠져야 한다(검토 11/5).
        if before.threeDaysBefore && !options.threeDaysBefore {
            await reminders.cancelTripReminders(kindSuffix: TripReminderPlanner.threeDaysBeforeSuffix)
        }
        if before.dayBefore && !options.dayBefore {
            await reminders.cancelTripReminders(kindSuffix: TripReminderPlanner.dayBeforeSuffix)
        }
        await replan()
    }

    func toggleDone(_ taskId: String) async {
        var state = self.state(for: taskId) ?? TripTaskState(taskId: taskId, isDone: false)
        state.isDone.toggle()
        state.doneAt = state.isDone ? now() : nil
        state.doneBy = state.isDone ? currentUserId : nil
        await write(apply: { $0.setState(state) }) {
            try await $0.provider.saveTaskState(state, tripId: $0.trip.id, babyId: $0.trip.babyId, userId: $0.ownerUserId)
        }
    }

    func setAssignee(_ assignee: TripAssignee, for taskId: String) async {
        guard assignee != .unknown else { return }
        var state = self.state(for: taskId) ?? TripTaskState(taskId: taskId, isDone: false)
        state.assignee = assignee
        await write(apply: { $0.setState(state) }) {
            try await $0.provider.saveTaskState(state, tripId: $0.trip.id, babyId: $0.trip.babyId, userId: $0.ownerUserId)
        }
    }

    func upsertBooking(_ booking: TripBooking) async {
        await write(apply: { trip in
            if let i = trip.bookings.firstIndex(where: { $0.id == booking.id }) { trip.bookings[i] = booking } else { trip.bookings.append(booking) }
        }) {
            try await $0.provider.saveBooking(booking, tripId: $0.trip.id, babyId: $0.trip.babyId, userId: $0.ownerUserId)
        }
    }

    func removeBooking(id: String) async {
        await write(apply: { $0.bookings.removeAll { $0.id == id } }) {
            try await $0.provider.deleteBooking(id, tripId: $0.trip.id, babyId: $0.trip.babyId, userId: $0.ownerUserId)
        }
    }

    func upsertMove(_ move: TripMove) async {
        await write(apply: { trip in
            if let i = trip.moves.firstIndex(where: { $0.id == move.id }) { trip.moves[i] = move } else { trip.moves.append(move) }
            trip.moves.sort { $0.startAt < $1.startAt }
        }) {
            try await $0.provider.saveMove(move, tripId: $0.trip.id, babyId: $0.trip.babyId, userId: $0.ownerUserId)
        }
    }

    func removeMove(id: String) async {
        await write(apply: { $0.moves.removeAll { $0.id == id } }) {
            try await $0.provider.deleteMove(id, tripId: $0.trip.id, babyId: $0.trip.babyId, userId: $0.ownerUserId)
        }
    }

    /// 도시·날짜 고치기 — 예약·체크는 그대로.
    func updateTripInfo(city: String, startDay: String, endDay: String) async {
        let name = city.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, startDay <= endDay else { return }
        await write(apply: { trip in
            trip.city = name
            trip.startDay = startDay
            trip.endDay = endDay
        }) {
            try await $0.provider.updateTripInfo(city: name, startDay: startDay, endDay: endDay,
                                                 tripId: $0.trip.id, babyId: $0.trip.babyId, userId: $0.ownerUserId)
        }
    }

    /// 화면에 먼저 반영 → 그 칸만 저장 → 실패하면 되돌리고 알림 · 성공하면 알림을 다시 건다.
    private func write(apply: (inout Trip) -> Void, save: (TripDetailViewModel) async throws -> Void) async {
        let before = trip
        var next = trip
        apply(&next)
        next.updatedAt = now()
        trip = next
        do {
            try await save(self)
            errorMessage = nil
        } catch {
            AppLogger.travel.error("여행 저장 실패: \(error.localizedDescription, privacy: .public)")
            trip = before
            errorMessage = "저장하지 못했어요. 다시 해 주세요."
            return
        }
        await replan()
    }

    /// 앞의 다시 걸기가 끝난 뒤 지금 상태로 건다(줄 세우기).
    private func replan(cancelOnly: Bool = false) async {
        let previous = replanTask
        let task = Task { @MainActor [weak self] in
            await previous?.value
            guard let self else { return }
            if cancelOnly || self.isDeleted {
                await self.reminders.cancelTripReminders(tripId: self.trip.id)
                return
            }
            let list = TripReminderPlanner.reminders(trip: self.trip, tasks: self.rawTasks, states: self.trip.taskStates,
                                                     now: self.now(), calendar: self.calendar, options: self.reminderOptions)
            await self.reminders.replaceTripReminders(tripId: self.trip.id, with: list)
        }
        replanTask = task
        await task.value
    }
}

private extension Trip {
    mutating func setState(_ state: TripTaskState) {
        if let i = taskStates.firstIndex(where: { $0.taskId == state.taskId }) {
            taskStates[i] = state
        } else {
            taskStates.append(state)
        }
    }
}

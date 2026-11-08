import Foundation

/// 최근 7일 이유식 기록에 고기가 들었나 — 이름 없는 기록이 있으면 모름(연동 명세의 세 값 + 이유식 없음).
enum MeatPresence: String, Hashable, Sendable {
    case present
    case absent
    case unknown
    case noSolids
}

/// 할 일을 정하는 데 쓰는 아기 정보 — 앱 안의 기록에서 바로 만든다.
struct TripChildContext: Hashable, Sendable {
    var birthDate: Date
    var heightCm: Double?
    var weightKg: Double?
    var meat: MeatPresence
    var hasSolids: Bool
}

struct TripDeadline: Hashable, Sendable {
    let label: String
    /// 마감 시각. 날짜만 아는 마감은 그날 끝으로 친다(순서·D-day 용 · 글자는 text 로).
    let at: Date
    var hasTime = true

    /// 「5.8(토) 15:10」 · 날짜만 알면 「5.7(금)」.
    func text(calendar: Calendar) -> String {
        hasTime ? TripDateText.dayTime(at, calendar: calendar) : TripDateText.day(at, calendar: calendar)
    }
}

/// 계산한 할 일 — 저장하지 않는다. id 는 규칙 키(+ 예약 id)라 다시 계산해도 완료 체크가 붙어 있다.
struct TripTask: Identifiable, Hashable, Sendable {
    let id: String
    let key: TripRuleKey
    let title: String
    let detail: String?
    let deadlines: [TripDeadline]
    /// 출발 시각을 몰라 아직 못 낸 마감 — 「오는 편」.
    var openDeadlines: [String] = []
    let recommendedOn: Date
    let childNote: String?
    let childNoteIsAlert: Bool
    let bookingId: String?

    var earliestDeadline: Date? { deadlines.map(\.at).min() }
}

/// 규칙과 예약에서 할 일을 만든다 — 설계서 §5. 순수 함수.
enum TripTaskEngine {

    static func tasks(trip: Trip, child: TripChildContext, now: Date, calendar: Calendar) -> [TripTask] {
        let start = Trip.date(fromDayKey: trip.startDay, calendar: calendar)
        let departure = start ?? calendar.startOfDay(for: now)
        let today = calendar.startOfDay(for: now)
        let isJapan = trip.countryCode.uppercased() == "JP"

        func recommended(_ deadlines: [TripDeadline]) -> Date {
            let anchor = deadlines.map(\.at).min() ?? departure
            let day = calendar.startOfDay(for: anchor)
            let candidate = calendar.date(byAdding: .day, value: -7, to: day) ?? day
            return max(candidate, today)
        }

        func legLabel(_ flight: TripBooking) -> String {
            flight.flightLeg ?? flight.flightNumber ?? "항공편"
        }

        var result: [TripTask] = []

        // 대한항공 편 — 시각 순. 출발 시각을 모르는 편은 마감을 지어내지 않고 「아직 못 낸 마감」으로 둔다(ADR-0001).
        let koreanAir = trip.bookings.filter { $0.kind == .flight && $0.airline?.uppercased() == TripRuleCatalog.koreanAir }
        let flights: [(TripBooking, Date)] = koreanAir.compactMap { b in b.depart?.time.map { (b, $0) } }.sorted { $0.1 < $1.1 }
        let openLegs = koreanAir.filter { $0.depart?.time == nil }.map(legLabel)

        if !koreanAir.isEmpty {
            let bassinetDeadlines = flights.map { flight, at in
                TripDeadline(label: legLabel(flight),
                             at: at.addingTimeInterval(-TimeInterval(TripRuleCatalog.bassinetDeadlineHours * 3600)))
            }
            let note = bassinetNote(child)
            result.append(TripTask(id: TripRuleKey.bassinet.rawValue, key: .bassinet, title: "배시넷 신청", detail: nil,
                                   deadlines: bassinetDeadlines, openDeadlines: openLegs, recommendedOn: recommended(bassinetDeadlines),
                                   childNote: note.text, childNoteIsAlert: note.isAlert, bookingId: nil))

            if months(from: child.birthDate, to: departure, calendar: calendar) < 24 {
                let mealDeadlines = flights.map { flight, at in
                    TripDeadline(label: legLabel(flight),
                                 at: at.addingTimeInterval(-TimeInterval(TripRuleCatalog.infantMealDeadlineHours * 3600)))
                }
                result.append(TripTask(id: TripRuleKey.infantMeal.rawValue, key: .infantMeal, title: "유아식 신청", detail: nil,
                                       deadlines: mealDeadlines, openDeadlines: openLegs, recommendedOn: recommended(mealDeadlines),
                                       childNote: nil, childNoteIsAlert: false, bookingId: nil))
            }
        }

        if isJapan, child.hasSolids {
            let note = solidsNote(child.meat)
            result.append(TripTask(id: TripRuleKey.solidsQuarantine.rawValue, key: .solidsQuarantine, title: "이유식 반입 계획",
                                   detail: nil, deadlines: [], recommendedOn: recommended([]),
                                   childNote: note.text, childNoteIsAlert: note.isAlert, bookingId: nil))
        }

        let underSix = months(from: child.birthDate, to: departure, calendar: calendar) < 72
        for booking in trip.bookings {
            let cancel = freeCancelDeadline(booking, calendar: calendar).map { [$0] } ?? []
            switch booking.kind {
            case .rentalCar where isJapan && underSix:
                result.append(TripTask(id: "\(TripRuleKey.carSeat.rawValue)-\(booking.id)", key: .carSeat, title: "렌터카 카시트 확인",
                                       detail: booking.company, deadlines: cancel, recommendedOn: recommended(cancel),
                                       childNote: nil, childNoteIsAlert: false, bookingId: booking.id))
            case .hotel:
                result.append(TripTask(id: "\(TripRuleKey.hotelCrib.rawValue)-\(booking.id)", key: .hotelCrib, title: "숙소에 아기침대 요청",
                                       detail: booking.name, deadlines: cancel, recommendedOn: recommended(cancel),
                                       childNote: nil, childNoteIsAlert: false, bookingId: booking.id))
            case .flight, .rentalCar, .unknown:
                break
            }
        }
        return result
    }

    /// 날짜만 아는 기한은 그날 끝까지다.
    private static func freeCancelDeadline(_ booking: TripBooking, calendar: Calendar) -> TripDeadline? {
        guard let when = booking.freeCancel else { return nil }
        if let time = when.time { return TripDeadline(label: "무료 취소 기한", at: time) }
        guard let day = when.startOfDay(calendar), let end = calendar.date(byAdding: .second, value: 86_399, to: day) else { return nil }
        return TripDeadline(label: "무료 취소 기한", at: end, hasTime: false)
    }

    private static func months(from birth: Date, to day: Date, calendar: Calendar) -> Int {
        calendar.dateComponents([.month], from: birth, to: day).month ?? 0
    }

    private static func bassinetNote(_ child: TripChildContext) -> (text: String, isAlert: Bool) {
        guard let h = child.heightCm, let w = child.weightKg else { return ("키·체중을 입력하면 알려 드려요", false) }
        if h <= TripRuleCatalog.bassinetMaxHeightCm && w <= TripRuleCatalog.bassinetMaxWeightKg {
            return ("우리 아이 해당(키·체중 기준 안)", false)
        }
        return ("키 75cm·체중 11kg을 넘으면 기내에서 못 쓸 수 있어요", true)
    }

    private static func solidsNote(_ meat: MeatPresence) -> (text: String?, isAlert: Bool) {
        switch meat {
        case .present: return ("최근 7일 이유식 기록에 고기 든 것이 있어요", true)
        case .absent: return ("최근 7일 이유식 기록 이름에서 고기를 찾지 못했어요", false)
        case .unknown: return ("이름 없는 이유식 기록이 있어 고기가 들었는지 몰라요", false)
        case .noSolids: return (nil, false)
        }
    }
}

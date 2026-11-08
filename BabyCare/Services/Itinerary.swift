import Foundation

/// 지도에 넘길 두 이름(TripRoutePlace.query 결과) — 구간 하나.
struct TripRouteKey: Hashable, Sendable {
    let from: String
    let to: String
}

/// 지도의 답. 사전에 키가 없으면 아직 모르는 것이다.
enum TripRouteAnswer: Hashable, Sendable {
    case found(RouteEstimate)
    case notFound
}

/// 일정표 — 예약·이동·아기 리듬으로 계산하는 여행일별 줄(GLOSSARY). 저장하지 않는다(ADR-0001).
/// 입구는 init 하나다 · async·던지기·현재 시각이 없어서 순서 제약이 없다.
/// 줄은 완성된 글자로 나온다 — 화면은 판단 없이 그린다. 규칙 = docs/superpowers/specs/2026-11-06-itinerary-design.md
struct Itinerary: Equatable, Sendable {
    let days: [Day]
    /// 예약 칸 — 가는 날 줄 + 다른 날 예약.
    let bookings: Bookings
    /// 지도에 아직 안 물은 구간. 줄의 개수·순서는 지도 답에 좌우되지 않는다.
    let routeQuestions: [TripRouteKey]

    init(trip: Trip, rhythm: BabyRhythm?, routes: [TripRouteKey: TripRouteAnswer] = [:], calendar: Calendar) {
        let walker = ItineraryWalker(trip: trip, rhythm: rhythm, routes: routes, calendar: calendar)
        var legs: [TripRouteKey] = []
        let dates = trip.days(calendar: calendar)
        days = dates.enumerated().map { index, date in
            let key = Trip.dayKey(date, calendar: calendar)
            let walked = walker.day(key)
            legs += walked.legs
            return Day(id: key, date: date, number: index + 1, title: Self.title(index: index, of: dates.count), tonight: walker.tonight(key),
                       lines: walked.lines, homeLines: walked.home)
        }
        bookings = walker.bookings()
        var seen = Set<TripRouteKey>()
        routeQuestions = legs.filter { routes[$0] == nil && seen.insert($0).inserted }
    }

    private static func title(index: Int, of count: Int) -> String {
        if index == 0 { return "출발하는 날" }
        if index == count - 1 { return "돌아오는 날" }
        return "여행 \(index + 1)일째"
    }

    /// 시각 미정 줄의 왼쪽 글자.
    static let openClock = "미정"

    /// 「15:10」.
    static func clock(_ date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
    }
}

extension Itinerary {
    struct Day: Identifiable, Hashable, Sendable {
        let id: String
        /// 그날 0시.
        let date: Date
        let number: Int
        /// 출발하는 날 · 여행 N일째 · 돌아오는 날.
        let title: String
        /// 오늘 밤 숙소.
        let tonight: String?
        let lines: [Line]
        /// 홈 「다음 일정」 — 그날 예약·이동(아기 줄 없음).
        let homeLines: [HomeLine]

        /// 비어 있는 시각이나 앞뒤가 안 맞는 줄이 있는 날.
        var needsAttention: Bool { lines.contains { $0.needsTime || $0.alert != nil } }
    }

    struct Line: Identifiable, Hashable, Sendable {
        /// 줄을 누르면 고치는 곳.
        enum Target: Hashable, Sendable {
            case booking(String)
            case move(String)
        }

        let id: String
        /// 「15:10」 「미정」 「」.
        var clock = ""
        /// 시각 아래 작은 말 — 빨라야 · 늦어도 · 까지 · 부터.
        var clockNote: String?
        let title: String
        var detail: String?
        /// 비어 있는 시각 — 그 줄에서 바로 넣게 한다.
        var needsTime = false
        /// 앞뒤가 안 맞는 것 — 체크인 마감을 넘김 등.
        var alert: String?
        var target: Target?
        var lane = Lane.travel
        /// 이 시각에 아기와 있는 공항 — 그 공항 수유실로 잇는다.
        var airportCode: String?
        /// 밤잠과 맞닿는 도착.
        var caution: Caution?
        /// 찾아낸 이동의 구간 — 구글지도로 길 보기.
        var route: TripRouteKey?
        /// 입국 규칙 카드로 잇는다.
        var rule: TripRuleKey?

        /// 왼쪽 시각이 「미정」인 줄.
        var isOpen: Bool { clock == Itinerary.openClock }
    }

    /// 홈 줄 — 편은 한 줄로 접고, 이동은 다음 줄 아래 글자로 들어간다.
    struct HomeLine: Identifiable, Hashable, Sendable {
        let id: String
        var clock = ""
        var clockNote: String?
        var isOpen = false
        let title: String
        var detail: String?
        /// 아이 칩 — 「낮잠 14:10과 탑승이 겹쳐요」.
        var childNote: String?
    }

    /// 예약 칸.
    struct Bookings: Equatable, Sendable {
        /// 「구글지도 기준」 — 가는 날 사이 이동의 출처.
        let sourceLabel: String?
        let dayOne: [Stop]
        let otherDays: [Stop]
    }

    /// 예약 칸 한 줄. 🔑 모든 예약이 둘 중 한 곳에 나온다 — 줄을 눌러 고치고 밀어서 지우는 길이 사라지지 않게.
    struct Stop: Identifiable, Hashable, Sendable {
        enum Kind: String, Hashable, Sendable {
            case flight, carPickup, carReturn, carRental, hotel
        }

        let kind: Kind
        let booking: TripBooking
        var clock = ""
        var clockNote: String?
        var isOpen = false
        let title: String
        /// 제목 아래 줄들.
        var details: [String] = []
        /// 다음 줄까지의 이동(가는 날만).
        var legAfter: Line?
        var caution: Caution?

        var id: String { "\(booking.id)-\(kind.rawValue)" }
    }

    /// 일정 칸의 줄 모양 — 여행(점) · 앱이 찾은 이동(점선) · 아기(상자).
    enum Lane: Hashable, Sendable {
        case travel, route, baby
    }

    struct Caution: Hashable, Sendable {
        let title: String
        let body: String
        /// 「빨라야 19:36에 닿고, 밤잠은 20:10이에요.」
        let timing: String
    }
}

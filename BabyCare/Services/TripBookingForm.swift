import Foundation

/// 예약 입력의 규칙 — 다듬기 · 저장 막는 까닭 · 기본값. 순수 함수(시트가 부른다).
enum TripBookingForm {

    /// 코드의 공백을 지우고 대문자로 — 「 KE」라고 넣어도 대한항공 규칙·공항 안내가 꺼지지 않게.
    static func normalized(_ booking: TripBooking) -> TripBooking {
        var b = booking
        b.airline = code(b.airline)
        b.flightNumber = code(b.flightNumber)
        b.fromAirport = code(b.fromAirport)
        b.toAirport = code(b.toAirport)
        b.name = text(b.name)
        b.address = text(b.address)
        b.company = text(b.company)
        b.pickupPlace = text(b.pickupPlace)
        b.returnPlace = text(b.returnPlace)
        b.pickupAddress = text(b.pickupAddress)
        b.returnAddress = text(b.returnAddress)
        return b
    }

    // MARK: - 렌터카 인수·반납 · 일정 출발·도착 — 찾아 고른 곳은 주소까지(숙소와 같은 규칙)

    enum RentalSpot { case pickup, carReturn }
    enum MoveEnd { case from, to }

    /// RED 판: 고치기 전 동작 그대로 — 이름만 넣는다.
    static func pickingRentalPlace(_ pick: PlaceSearchModel.Pick, at spot: RentalSpot, into booking: TripBooking) -> TripBooking {
        var b = booking
        switch spot {
        case .pickup: b.pickupPlace = pick.name
        case .carReturn: b.returnPlace = pick.name
        }
        return b
    }

    /// RED 판: 고치기 전 동작 그대로 — 이름만 바꾼다.
    static func typingRentalPlace(_ text: String?, at spot: RentalSpot, into booking: TripBooking) -> TripBooking {
        var b = booking
        switch spot {
        case .pickup: b.pickupPlace = text
        case .carReturn: b.returnPlace = text
        }
        return b
    }

    /// RED 판: 고치기 전 동작 그대로 — 이름만 넣는다.
    static func pickingMovePlace(_ pick: PlaceSearchModel.Pick, at end: MoveEnd, into move: TripMove) -> TripMove {
        var m = move
        switch end {
        case .from: m.fromLabel = pick.name
        case .to: m.toLabel = pick.name
        }
        return m
    }

    /// RED 판: 고치기 전 동작 그대로 — 이름만 바꾼다.
    static func typingMovePlace(_ text: String, at end: MoveEnd, into move: TripMove) -> TripMove {
        var m = move
        switch end {
        case .from: m.fromLabel = text
        case .to: m.toLabel = text
        }
        return m
    }

    /// 일정 넣는 창이 차 시간을 물을 글자. RED 판: 고치기 전 동작 그대로 — 이름.
    static func routeText(for move: TripMove, at end: MoveEnd) -> String {
        end == .from ? move.fromLabel : move.toLabel
    }

    /// 숙소를 고른 결과 — 이름과 주소를 함께 바꾼다.
    /// 🔴 다른 이름을 직접 입력하면 주소를 비운다: 주소 칸이 없어 고칠 길이 없고, 길찾기는 주소를 먼저 봐서 옛 숙소로 간다.
    ///    같은 이름을 다시 누른 것뿐이면 주소를 지킨다.
    static func pickingHotel(_ pick: PlaceSearchModel.Pick, into booking: TripBooking) -> TripBooking {
        var b = booking
        if pick.address != nil || pick.name != booking.name {
            b.address = pick.address
        }
        b.name = pick.name
        return b
    }

    /// 저장을 막는 까닭(nil = 저장 가능). 다듬은 값으로 본다.
    /// ⛔ 시각을 요구하지 않는다 — 날짜만 알면 저장하고 일정표가 「미정」으로 묻는다(ADR-0001).
    static func problem(_ booking: TripBooking, calendar: Calendar) -> String? {
        let b = normalized(booking)
        switch b.kind {
        case .flight:
            if b.airline == nil { return "항공사 코드를 입력해 주세요" }
            if b.flightNumber == nil { return "편명을 입력해 주세요" }
            if b.depart == nil && b.arrive == nil { return "날짜를 골라 주세요" }
            if let dep = b.depart?.time, let arr = b.arrive?.time, arr <= dep { return "도착이 출발보다 늦어야 해요" }
        case .hotel:
            if b.name == nil { return "숙소 이름을 입력해 주세요" }
            guard let start = b.checkIn else { return "체크인 날짜를 골라 주세요" }
            if let end = b.checkOut, !isAfter(end, start, calendar: calendar) { return "체크아웃이 체크인보다 늦어야 해요" }
        case .rentalCar:
            guard let start = b.pickup else { return "인수 날짜를 골라 주세요" }
            if let end = b.carReturn, !isAfter(end, start, sameDayIsFine: true, calendar: calendar) { return "반납이 인수보다 늦어야 해요" }
        case .unknown:
            return "이 예약은 새 버전 앱에서 수정할 수 있어요"
        }
        return nil
    }

    /// 둘 다 시각을 알면 시각으로, 아니면 날짜로 잰다. 시각을 모르는 같은 날은 앞뒤를 모른다 — 당일 렌터카는 막지 않는다.
    private static func isAfter(_ later: TripWhen, _ earlier: TripWhen, sameDayIsFine: Bool = false, calendar: Calendar) -> Bool {
        if let a = later.time, let b = earlier.time { return a > b }
        let (a, b) = (later.dayKey(calendar), earlier.dayKey(calendar))
        return sameDayIsFine ? a >= b : a > b
    }

    /// 새 예약 — 날짜만 여행 첫날로 두고 시각은 비운다. 🩸 14:00 을 넣어 두었더니 일정표에 지어낸 시각이 나왔다(2026-11-06).
    /// 항공사·편명도 비워 둔다(미리 채우면 다른 항공사가 대한항공 마감을 물려받는다).
    static func newBooking(_ kind: TripBooking.Kind, tripStart: Date, calendar: Calendar) -> TripBooking {
        let first = TripWhen.day(Trip.dayKey(tripStart, calendar: calendar))
        let next = (calendar.date(byAdding: .day, value: 1, to: tripStart)).map { TripWhen.day(Trip.dayKey($0, calendar: calendar)) }
        switch kind {
        case .flight: return TripBooking(kind: .flight)
        case .hotel: return TripBooking(kind: .hotel, checkIn: first, checkOut: next)
        case .rentalCar: return TripBooking(kind: .rentalCar, pickup: first, carReturn: next)
        case .unknown: return TripBooking(kind: .hotel)
        }
    }

    private static func code(_ s: String?) -> String? {
        guard let s else { return nil }
        let v = s.uppercased().filter { !$0.isWhitespace }
        return v.isEmpty ? nil : v
    }

    private static func text(_ s: String?) -> String? {
        guard let s else { return nil }
        let v = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return v.isEmpty ? nil : v
    }
}

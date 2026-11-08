import SwiftUI

/// 규칙 칸(시안 「여행: 규칙」) — 이 여행의 규칙(출처 12 · 규칙 15 · 「우리 아이 해당」 빨강) · 띠 · 공항 시설 안내 상자.
/// TravelList 안에서 줄 여러 개를 낸다.
struct TripRulesSection: View {
    let vm: TripDetailViewModel
    @State private var openedCard: TripRuleCard?

    var body: some View {
        let cards = vm.ruleCards
        let airports = vm.airports
        let hasNonKoreanAir = vm.trip.bookings.contains {
            $0.kind == .flight && ($0.airline ?? "").uppercased() != TripRuleCatalog.koreanAir
        }

        TravelSectionHeader(title: "이 여행의 규칙", trailing: "아이 정보와 예약으로 골랐어요")
            .padding(.top, 4)
            .travelRow()
        if cards.isEmpty {
            Text("예약을 추가하면 이 여행에 걸리는 규칙이 보여요.")
                .travelFont(14)
                .foregroundStyle(TravelStyle.sub)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .top) { TravelHairline() }
                .travelRow()
        }
        ForEach(cards, id: \.key) { card in
            let task = vm.tasks.first { $0.key == card.key }
            Button {
                openedCard = card
            } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(card.sources.first?.title ?? "챙기면 좋은 일")
                            .travelFont(12)
                            .foregroundStyle(TravelStyle.sub)
                            .lineLimit(1)
                        Text(card.title)
                            .travelFont(15)
                            .travelLineHeight(1.4, size: 15)
                            .foregroundStyle(TravelStyle.ink)
                        if task?.childNoteIsAlert == true {
                            Text("우리 아이 해당")
                                .travelFont(12, .semibold)
                                .foregroundStyle(TravelStyle.red)
                        }
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(TravelStyle.checkBorder)
                }
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .top) { TravelHairline() }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .travelRow()
        }
        if hasNonKoreanAir {
            Text("대한항공이 아닌 항공사 규칙은 아직 없어요.")
                .travelFont(13)
                .foregroundStyle(TravelStyle.sub)
                .padding(.bottom, 8)
                .travelRow()
        }
        TravelBandRow()
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("공항 시설 안내")
                    .travelFont(16, .semibold)
                    .foregroundStyle(TravelStyle.ink)
                Spacer()
                Text("수유실·기저귀 교환대")
                    .travelFont(13)
                    .foregroundStyle(TravelStyle.sub)
            }
            if airports.isEmpty {
                Text("항공편을 추가하면 출발·도착 공항 안내가 보여요.")
                    .travelFont(14)
                    .foregroundStyle(TravelStyle.sub)
            }
            ForEach(airports, id: \.code) { a in
                if let f = a.facility {
                    TravelAirportBox(facility: f, flights: flightLine(a.code))
                } else {
                    Text("\(a.code) — 이 공항은 아직 정보가 없어요")
                        .travelFont(14)
                        .foregroundStyle(TravelStyle.sub)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .travelRow(top: 14, bottom: 16)
        .sheet(item: $openedCard) { card in
            TripRuleCardSheet(card: card, childNote: vm.tasks.first { $0.key == card.key }?.childNote)
        }
    }

    /// 「5.10(월) 15:10 KE725 출발 · 5.14(금) 14:00 KE724 도착」 — 그 공항을 쓰는 편.
    private func flightLine(_ code: String) -> String? {
        let cal = vm.calendar
        var parts: [String] = []
        for f in vm.flightBookings {
            let number = f.flightNumber ?? ""
            if f.fromAirport?.uppercased() == code, let d = f.depart ?? f.arrive {
                parts.append("\(f.depart?.time == nil ? TripDateText.day(d, calendar: cal) : TripDateText.when(d, calendar: cal)) \(number) 출발")
            }
            if f.toAirport?.uppercased() == code, let a = f.arrive ?? f.depart {
                parts.append("\(f.arrive?.time == nil ? TripDateText.day(a, calendar: cal) : TripDateText.when(a, calendar: cal)) \(number) 도착")
            }
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

/// 공항 시설 상자(시안: #F7F8FA · 모서리 8 · 여백 12/14 · 이름 칸 92 · 14).
struct TravelAirportBox: View {
    let facility: AirportFacility
    let flights: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(facility.airportName) \(facility.terminal)")
                    .travelFont(15, .semibold)
                    .foregroundStyle(TravelStyle.ink)
                if let flights {
                    Text(flights)
                        .travelFont(13)
                        .foregroundStyle(TravelStyle.sub)
                        .monospacedDigit()
                }
            }
            Grid(alignment: .topLeading, horizontalSpacing: 0, verticalSpacing: 6) {
                GridRow {
                    label("수유실")
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(facility.rooms, id: \.self) { room in
                            Text(room.line)
                                .travelFont(14)
                                .foregroundStyle(TravelStyle.ink)
                            if let sub = room.sub {
                                Text(sub)
                                    .travelFont(13)
                                    .foregroundStyle(TravelStyle.sub)
                                    .monospacedDigit()
                            }
                        }
                    }
                }
                GridRow {
                    label("기저귀 교환대")
                    Text(facility.diaper)
                        .travelFont(14)
                        .foregroundStyle(TravelStyle.ink)
                }
            }
            if let caution = facility.caution {
                Text(caution)
                    .travelFont(13)
                    .travelLineHeight(1.45, size: 13)
                    .foregroundStyle(TravelStyle.sub)
            }
            Link(destination: facility.source.url) {
                TravelLinkLabel(text: "공항 안내 보기 · 확인일 \(facility.source.checkedOn)")
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(TravelStyle.box))
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .travelFont(14)
            .foregroundStyle(TravelStyle.sub)
            .frame(width: 92, alignment: .leading)
    }
}

/// 공항 시설 안내 한 장(일정 칸 「수유실 보기」) — 규칙 칸과 같은 상자.
struct AirportFacilitySheet: View {
    let facility: AirportFacility
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                TravelAirportBox(facility: facility, flights: nil)
                    .padding(TravelStyle.gutter)
            }
            .background(TravelStyle.page)
            .navigationTitle("\(facility.airportName) \(facility.terminal)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("닫기") { dismiss() }
                }
            }
        }
    }
}

extension TripRuleCard: Identifiable {
    var id: String { key.rawValue }
}

extension AirportFacility: Identifiable {
    var id: String { "\(airportCode)-\(terminal)" }
}

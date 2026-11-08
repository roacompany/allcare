import SwiftUI

/// 일정 칸 — 날짜를 고르면 그날 일정표(예약 · 찾아낸 이동 · 아기 리듬). 줄은 Itinerary 가 완성해서 준다.
struct TripScheduleSection: View {
    let vm: TripDetailViewModel
    /// 고른 날 — 여행 공간이 쥐면 홈 「일정 전체」가 그날로 바꾼다(없으면 이 칸 안에서만 기억).
    var selection: Binding<Date?>?
    /// 「+ 일정 추가」(시안 Day-Plan) — 고른 날.
    var onAddMove: (Date) -> Void = { _ in }
    /// 줄을 누르면 그 예약·일정을 고친다.
    var onEdit: (Itinerary.Line.Target) -> Void = { _ in }
    /// 「아기침대 요청 할 일 보기」.
    var onShowTasks: () -> Void = {}
    @State private var localDay: Date?
    @State private var openedFacility: AirportFacility?
    @State private var openedRule: TripRuleCard?

    private var cal: Calendar { vm.calendar }

    /// 고른 날이 여행 기간 밖이면(기간을 고친 뒤) 오늘 · 첫날로 돌아간다.
    private var day: Date? {
        if let picked = selection?.wrappedValue ?? localDay, let match = vm.days.first(where: { cal.isDate($0, inSameDayAs: picked) }) {
            return match
        }
        let today = cal.startOfDay(for: vm.today)
        return vm.days.first { $0 == today } ?? vm.days.first
    }

    private func select(_ d: Date) {
        if let selection {
            selection.wrappedValue = d
        } else {
            localDay = d
        }
    }

    /// 시안 Day-Plan — 날짜 칸(「1일차」 14 굵게 / 「5.10(월)」 12 · 높이 52 · 둥근 8 · 고른 칸 파란 테두리 1.5·파란 글 · 시각 미정이 있는 날 점)
    /// · 띠 · 그날 제목 + 오늘 밤 + 설명 + 범례 · 시간 줄(시각 44 · 선 16 · 내용).
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 5), spacing: 6) {
            ForEach(vm.itinerary.days) { d in
                dayChip(d)
            }
        }
        .travelRow(top: 12, bottom: 12)
        TravelBandRow()

        if let day, let plan = vm.itinerary.days.first(where: { $0.date == day }) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center, spacing: 8) {
                    Text(plan.title)
                        .travelFont(16, .semibold)
                        .foregroundStyle(TravelStyle.ink)
                    Spacer(minLength: 8)
                    TravelAddChip(title: "일정 추가") { onAddMove(day) }
                }
                if let tonight = plan.tonight {
                    HStack(spacing: 6) {
                        Image(systemName: "bed.double")
                            .font(.system(size: 13))
                            .foregroundStyle(TravelStyle.sub)
                        Text("오늘 밤")
                            .foregroundStyle(TravelStyle.body)
                        Text(tonight)
                            .fontWeight(.semibold)
                            .foregroundStyle(TravelStyle.ink)
                    }
                    .travelFont(14)
                    .padding(.top, 2)
                    .padding(.bottom, 4)
                    .accessibilityElement(children: .combine)
                }
                Text(rhythmNote)
                    .travelFont(13)
                    .travelLineHeight(1.5, size: 13)
                    .foregroundStyle(TravelStyle.sub)
                HStack(spacing: 14) {
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 2).fill(TravelStyle.babyBox).frame(width: 14, height: 10)
                        Text("아이 잠·수유·이유식")
                    }
                    HStack(spacing: 6) {
                        Circle().fill(TravelStyle.ink).frame(width: 8, height: 8)
                        Text("비행·이동·예약")
                    }
                }
                .travelFont(12)
                .foregroundStyle(TravelStyle.sub)
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .travelRow(top: 16, bottom: 14)
            if plan.lines.isEmpty {
                Text("이날은 등록한 예약이 없어요.")
                    .travelFont(14)
                    .foregroundStyle(TravelStyle.sub)
                    .travelRow(bottom: 12)
            }
            ForEach(Array(plan.lines.enumerated()), id: \.element.id) { index, line in
                TripItineraryLineRow(line: line, facility: facility(for: line), isFirst: index == 0, isLast: index == plan.lines.count - 1,
                                     onFacility: { openedFacility = $0 },
                                     onRule: { openedRule = TripRuleCatalog.card($0) },
                                     onEdit: onEdit, onShowTasks: onShowTasks)
                    .travelRow()
            }
            Color.clear
                .frame(height: 16)
                .travelRow()
                .sheet(item: $openedFacility) { f in
                    AirportFacilitySheet(facility: f)
                }
                .sheet(item: $openedRule) { card in
                    TripRuleCardSheet(card: card, childNote: vm.tasks.first { $0.key == card.key }?.childNote)
                }
        }
    }

    private func dayChip(_ d: Itinerary.Day) -> some View {
        let selected = d.date == day
        let name = TripDateText.day(d.date, calendar: cal)
        return Button { select(d.date) } label: {
            VStack(spacing: 2) {
                Text("\(d.number)일차")
                    .travelFont(14, .bold)
                Text(name)
                    .travelFont(12)
                    .monospacedDigit()
            }
            .foregroundStyle(selected ? TravelStyle.primary : TravelStyle.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(RoundedRectangle(cornerRadius: 8).fill(TravelStyle.page))
            .overlay(RoundedRectangle(cornerRadius: 8)
                .strokeBorder(selected ? TravelStyle.primary : TravelStyle.cardBorder, lineWidth: selected ? 1.5 : 1))
            .overlay(alignment: .topTrailing) {
                if d.needsAttention {
                    Circle().fill(TravelStyle.amber).frame(width: 6, height: 6).padding(6)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("\(d.number)일차, \(name)" + (d.needsAttention ? ", 확인할 것 있음" : ""))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var rhythmNote: String {
        if vm.childLoadFailed { return "아기 기록을 불러오지 못했어요. 낮잠·수유 시간이 빠져 있어요." }
        guard let rhythm = vm.rhythm else { return "아기 기록이 있으면 낮잠·수유 시간을 같이 보여 드려요." }
        return "베이비케어 최근 7일 기록으로 계산한 아이 리듬 위에 비행과 운전을 놓았어요." + (rhythm.isRough ? " 기록이 적어 대략이에요." : "")
    }

    private func facility(for line: Itinerary.Line) -> AirportFacility? {
        guard let code = line.airportCode else { return nil }
        return vm.airports.first { $0.code == code.uppercased() && $0.facility != nil }?.facility
    }
}

/// 일정 한 줄(시안) — 시각 44(14 굵게 · 아래 작은 말) · 선 16(아이 = 빈 점 · 여행 = 검은 점 · 찾아낸 이동 = 점선) · 내용(아이는 상자).
/// 🩸 줄 안에 Link·Button 을 두면 그것이 줄 전체의 탭을 가져간다 — 글자 고리는 제스처로 제 자리만 받는다(2026-11-06).
struct TripItineraryLineRow: View {
    let line: Itinerary.Line
    let facility: AirportFacility?
    var isFirst = false
    var isLast = false
    let onFacility: (AirportFacility) -> Void
    let onRule: (TripRuleKey) -> Void
    let onEdit: (Itinerary.Line.Target) -> Void
    let onShowTasks: () -> Void

    @Environment(\.openURL) private var openURL

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 0) {
                Text(line.clock)
                    .travelFont(14, .bold)
                    .foregroundStyle(line.isOpen ? TravelStyle.amber : TravelStyle.ink)
                    .monospacedDigit()
                if let note = line.clockNote {
                    Text(note)
                        .travelFont(11)
                        .foregroundStyle(TravelStyle.sub)
                }
            }
            .padding(.top, 8)
            .frame(width: 44, alignment: .leading)
            rail
                .frame(width: 16)
            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var rail: some View {
        ZStack(alignment: .top) {
            if line.lane == .route {
                TravelDashedRail()
                    .stroke(TravelStyle.checkBorder, style: StrokeStyle(lineWidth: 2, dash: [3, 3]))
                    .frame(maxHeight: .infinity)
            } else {
                TravelStyle.cardBorder
                    .frame(width: 2)
                    .padding(.top, isFirst ? 18 : 0)
                    .frame(maxHeight: isLast ? 18 : .infinity, alignment: .top)
                    .frame(maxHeight: .infinity, alignment: .top)
                dot
                    .frame(width: 10, height: 10)
                    .padding(.top, 13)
            }
        }
    }

    @ViewBuilder
    private var dot: some View {
        if line.lane == .baby {
            Circle()
                .strokeBorder(TravelStyle.babyDot, lineWidth: 2)
                .background(Circle().fill(TravelStyle.page))
        } else {
            Circle()
                .fill(line.isOpen ? TravelStyle.amber : line.caution != nil ? TravelStyle.red : TravelStyle.ink)
                .overlay(Circle().stroke(TravelStyle.page, lineWidth: 3))
        }
    }

    @ViewBuilder
    private var content: some View {
        switch line.lane {
        case .baby:
            VStack(alignment: .leading, spacing: 2) {
                title(15)
                detail
                facilityLink
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 6).fill(TravelStyle.babyBox))
            .padding(.bottom, 10)
        case .route:
            VStack(alignment: .leading, spacing: 0) {
                title(13)
                detail
                if let route = line.route, let url = GoogleMapsLink.directions(from: route.from, to: route.to) {
                    tapLink("구글지도로 길 보기") { openURL(url) }
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 10)
        case .travel:
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        title(15)
                        detail
                    }
                    Spacer(minLength: 0)
                    if line.rule != nil {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(TravelStyle.sub)
                            .padding(.top, 4)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture(perform: tap)
                if let alert = line.alert {
                    Text(alert)
                        .travelFont(13, .semibold)
                        .foregroundStyle(TravelStyle.amber)
                        .monospacedDigit()
                }
                if line.needsTime, let target = line.target {
                    tapLink("시각 넣기") { onEdit(target) }
                        .accessibilityIdentifier("itinerary.fillTime")
                }
                facilityLink
                if let caution = line.caution {
                    cautionBox(caution)
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 14)
        }
    }

    private func tap() {
        if let rule = line.rule {
            onRule(rule)
        } else if let target = line.target {
            onEdit(target)
        }
    }

    private func title(_ size: CGFloat) -> some View {
        Text(line.title)
            .travelFont(size)
            .foregroundStyle(line.lane == .route ? TravelStyle.body : TravelStyle.ink)
            .monospacedDigit()
    }

    @ViewBuilder
    private var detail: some View {
        if let detail = line.detail {
            Text(detail)
                .travelFont(13)
                .foregroundStyle(TravelStyle.sub)
                .monospacedDigit()
        }
    }

    @ViewBuilder
    private var facilityLink: some View {
        if let facility {
            tapLink("\(facility.airportName) 수유실 보기") { onFacility(facility) }
        }
    }

    private func cautionBox(_ caution: Itinerary.Caution) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(caution.title)
                .travelFont(13, .semibold)
                .foregroundStyle(TravelStyle.red)
            Text(caution.body)
                .travelFont(13)
                .travelLineHeight(1.5, size: 13)
                .foregroundStyle(TravelStyle.body)
            tapLink("아기침대 요청 할 일 보기", action: onShowTasks)
        }
        .padding(.top, 10)
        .padding(.bottom, 4)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 6).fill(TravelStyle.redSoft))
        .padding(.top, 8)
    }

    private func tapLink(_ text: String, action: @escaping () -> Void) -> some View {
        TravelLinkLabel(text: text)
            .contentShape(Rectangle())
            .onTapGesture(perform: action)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(text)
            .accessibilityAddTraits(.isButton)
    }
}

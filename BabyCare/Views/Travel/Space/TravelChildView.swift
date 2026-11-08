import SwiftUI

/// 여행 공간 아이 칸(시안 아이) — 베이비케어 기록 그대로 · 수정은 베이비케어 설정에서.
struct TravelChildView: View {
    let vm: TripDetailViewModel

    /// 시안 아이 — 머리(20 굵게 「아이」 · 13 회색) · 프로필 표(이름 칸 88 · 값 15 · 쓰임 12) · 띠 · 베이비케어 기록 상자.
    var body: some View {
        TravelList {
            VStack(alignment: .leading, spacing: 4) {
                Text("아이")
                    .travelFont(20, .bold, tracking: -0.02)
                    .foregroundStyle(TravelStyle.ink)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .travelRow(top: 16, bottom: 4)
            if vm.childLoadFailed {
                Label("아기 기록을 불러오지 못했어요. 낮잠·수유 시간이 빠져 있어요.", systemImage: "exclamationmark.circle")
                    .travelFont(13)
                    .foregroundStyle(TravelStyle.red)
                    .padding(.vertical, 8)
                    .travelRow()
            }
            TravelSectionHeader(title: "프로필")
                .padding(.top, 4)
                .travelRow()
            row("생년월일", lines: [birthLine], first: true)
            row("키·체중", lines: growthLines)
            row("먹는 것", lines: foodLines)
            row("낮잠", lines: napLines)
            row("밤잠·기상", lines: [TravelChildText.sleep(bedtime: vm.rhythm?.bedtimeMinute, wake: vm.rhythm?.wakeMinute) ?? "기록 없음"])
                .padding(.bottom, 8)
            TravelBandRow()
            VStack(alignment: .leading, spacing: 10) {
                Text("베이비케어 기록")
                    .travelFont(16, .semibold)
                    .foregroundStyle(TravelStyle.ink)
                VStack(alignment: .leading, spacing: 3) {
                    Text("최근 7일 기록으로 계산해요")
                        .travelFont(15, .semibold)
                        .foregroundStyle(TravelStyle.ink)
                    Text(TravelChildText.coverage(daysWithRecords: vm.rhythm?.daysWithRecords ?? 0)
                         + (vm.rhythm?.isRough == true ? " · 기록이 적어 대략이에요" : ""))
                        .travelFont(13)
                        .travelLineHeight(1.45, size: 13)
                        .foregroundStyle(TravelStyle.sub)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 8).fill(TravelStyle.box))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .travelRow(top: 16, bottom: 20)
        }
    }

    // MARK: - 줄(시안: 이름 칸 88 · 사이 12 · 위아래 10 · 위 1px 선 — 첫 줄만 #DDE1E6)

    private func row(_ title: String, lines: [String], first: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title)
                .travelFont(13)
                .foregroundStyle(TravelStyle.sub)
                .padding(.top, 2)
                .frame(width: 88, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                ForEach(lines, id: \.self) { line in
                    Text(line)
                        .travelFont(15)
                        .travelLineHeight(1.45, size: 15)
                        .foregroundStyle(TravelStyle.ink)
                        .monospacedDigit()
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
        .overlay(alignment: .top) {
            (first ? TravelStyle.tableTop : TravelStyle.line).frame(height: 1)
        }
        .travelRow()
    }

    private var birthLine: String {
        let start = Trip.date(fromDayKey: vm.trip.startDay, calendar: vm.calendar) ?? vm.today
        let months = TravelChildText.months(at: start, birthDate: vm.child.birthDate, calendar: vm.calendar)
        let parts = vm.calendar.dateComponents([.year, .month, .day], from: vm.child.birthDate)
        let date = "\(parts.year ?? 0).\(parts.month ?? 0).\(parts.day ?? 0)"
        return "\(date), 출발일에 \(months)개월"
    }

    private var growthLines: [String] {
        var lines: [String] = []
        if let h = vm.latestHeight { lines.append("키 \(Self.number(h.value))cm, \(measured(h.measuredOn)) 측정") }
        if let w = vm.latestWeight { lines.append("체중 \(Self.number(w.value))kg, \(measured(w.measuredOn)) 측정") }
        return lines.isEmpty ? ["성장 기록이 없어요"] : lines
    }

    private var foodLines: [String] {
        var lines: [String] = []
        switch vm.child.meat {
        case .present: lines.append("이유식(고기 든 것 있음)")
        case .absent: lines.append("이유식(고기 없음)")
        case .unknown: lines.append("이유식(고기 든 것인지 모름)")
        case .noSolids: lines.append("이유식 기록 없음")
        }
        if let feed = TravelChildText.feedInterval(vm.rhythm?.dayFeedIntervalMin) { lines.append(feed) }
        return lines
    }

    private var napLines: [String] {
        guard let rhythm = vm.rhythm else { return ["기록 없음"] }
        var lines = [TravelChildText.naps(rhythm.naps) ?? "낮잠 기록 없음"]
        if rhythm.carSeatNaps > 0 { lines.append("카시트에서 잔 낮잠 \(rhythm.carSeatNaps)번") }
        return lines
    }

    private func measured(_ date: Date) -> String {
        let parts = vm.calendar.dateComponents([.month, .day], from: date)
        return "\(parts.month ?? 0).\(parts.day ?? 0)"
    }

    /// 70.5 → "70.5", 8.0 → "8"
    private static func number(_ value: Double) -> String {
        value.rounded() == value ? String(Int(value)) : String(format: "%.1f", value)
    }
}

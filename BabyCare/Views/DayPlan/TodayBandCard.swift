import SwiftUI

/// 띠 카드가 하는 말. 화면에서 떼어 내 테스트로 잠근다.
/// ⛔ 지연·재촉·완료율 분수·연속 일수는 **어떤 상태에서도** 나오지 않는다(설계 §2 결정 6 · §5).
enum TodayBandCopy {

    private static let korean = ["한", "두", "세", "네", "다섯", "여섯", "일곱", "여덟", "아홉", "열"]

    static func headline(run: DayRun?, cells: [DayCell]) -> String {
        guard let run else { return "우리 하루" }
        if !run.isOpen { return "오늘도 잘 지났어요" }
        if cells.contains(where: { $0.kind == .extra }) {
            return "오늘은 \(count(cells.count)) 칸이 됐어요"
        }
        let done = cells.filter { $0.kind == .done }.count
        return done == 0 ? "첫 기록을 기다리는 중" : "\(count(done)) 칸 지났어요"
    }

    /// 헤드라인 바로 아래 둘째 줄 — **설명이 필요한 두 상태에만** 있다(시안 「① 아침」의 두 줄 ·
    /// fix round 1 Finding 2). 헤드라인이 「우리 하루」/「N 칸 지났어요」처럼 이름·상태만 말하게
    /// 되면서, "왜 기다리나 · 열면 무슨 일이 있나"는 이 줄이 옮겨 받았다. 낮(이미 진행 중이라
    /// 설명이 필요 없다)·밤(헤드라인 + `summaryLine`으로 충분하다)은 `nil` — 화면에 아예 안 그려진다.
    static func subheadline(run: DayRun?, cells: [DayCell]) -> String? {
        guard let run else { return "오늘을 열면 짜 둔 시간표가 하루 동안 흐릅니다" }
        guard run.isOpen else { return nil }
        if cells.contains(where: { $0.kind == .extra }) { return nil }
        let done = cells.filter { $0.kind == .done }.count
        return done == 0 ? "첫 기록이 오면 오늘 시간이 정해져요" : nil
    }

    static func count(_ n: Int) -> String {
        n >= 1 && n <= korean.count ? korean[n - 1] : "\(n)"
    }
}

/// 하루 띠 카드 — 시작 전 · 아침 · 낮 · 밤(닫힘) 네 상태를 그린다(시안 정본).
/// 열고 · 기록이 칸을 채우고 · 닫는다 — 부모가 처음으로 「우리 하루」를 볼 수 있는 자리.
/// ⛔ 빨간색·경고 아이콘·「N/M」·「지연」 배지 없음.
struct TodayBandCard: View {
    @Environment(AuthViewModel.self) private var authVM
    @Environment(BabyViewModel.self) private var babyVM
    @Environment(ActivityViewModel.self) private var activityVM

    @State private var vm = TodayViewModel()

    /// 🔴 `currentUserId` 를 **먼저** — `dataUserId` 는 로그아웃 뒤에도 소유자 uid 를 돌려준다(#49).
    private var ownerUserId: String? {
        guard let current = authVM.currentUserId else { return nil }
        return babyVM.dataUserId(currentUserId: current) ?? current
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS2.Spacing.md) {
            Text(TodayBandCopy.headline(run: vm.run, cells: vm.cells))
                .font(DS2.Font.headline)
                .foregroundStyle(DS2.Color.textPrimary)

            if let sub = TodayBandCopy.subheadline(run: vm.run, cells: vm.cells) {
                Text(sub)
                    .font(DS2.Font.subheadline)
                    .foregroundStyle(DS2.Color.textSecondary)
            }

            if vm.run == nil {
                startButton
            } else {
                DayBandStrip(cells: vm.cells)
                if vm.run?.isOpen == false, let name = babyVM.selectedBaby?.name,
                   let line = vm.summaryLine(babyName: name) {
                    Text(line)
                        .font(DS2.Font.callout)
                        .foregroundStyle(DS2.Color.textSecondary)
                }
                if vm.run?.isOpen == true { closeButton }
            }
        }
        .padding(DS2.Spacing.lg)
        .background(DS2.Color.surfaceSecondary, in: RoundedRectangle(cornerRadius: DS2.Radius.md))
        .ds2Shadow(.sm)
        .task {
            guard let userId = ownerUserId else { return }
            await vm.load(userId: userId, day: Date(), activities: activityVM.todayActivities)
        }
        // 기록이 들어오면 칸이 채워진다 — 저장소를 다시 두드리지 않는다.
        .onChange(of: activityVM.todayActivities) { _, new in
            vm.refreshCells(day: Date(), activities: new)
        }
    }
    private var startButton: some View {
        Button {
            Task {
                guard let userId = ownerUserId else { return }
                await vm.startToday(userId: userId, day: Date())
            }
        } label: {
            Text("오늘 하루 시작하기")
                .font(DS2.Font.callout)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS2.Spacing.sm)
                // 🩸 `.buttonStyle` 을 바꾸면 **글자 자리만** 눌린다 — ①단계에서 두 곳이 그랬다.
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderedProminent)
        .tint(DS2.Color.accent)
        .accessibilityHint("눌러서 오늘 하루를 엽니다")
    }

    private var closeButton: some View {
        Button {
            Task {
                guard let userId = ownerUserId else { return }
                await vm.closeToday(userId: userId)
            }
        } label: {
            Text("오늘도 잘 지났어요")
                .font(DS2.Font.callout)
                .foregroundStyle(DS2.Color.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS2.Spacing.xs)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("눌러서 오늘 하루를 닫습니다")
    }
}

/// 하루 띠. 채워진 점 · 지금 고리 · 빈 점 · 끼어든 칸(테두리).
/// ⛔ 빨간색·경고 아이콘 없음 — 안 온 칸은 **그냥 빈 점**이다.
private struct DayBandStrip: View {
    let cells: [DayCell]

    /// 지금에 가장 가까운 **시각이 있는** 칸 — 여기에만 큰 고리를 두른다.
    private var nowCellId: String? {
        let now = Date()
        return cells
            .filter { $0.at != nil }
            .min { abs($0.at!.timeIntervalSince(now)) < abs($1.at!.timeIntervalSince(now)) }?
            .id
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS2.Spacing.md) {
                ForEach(cells) { cell in
                    VStack(spacing: DS2.Spacing.xs) {
                        dot(cell)
                            .frame(width: 20, height: 20)
                            .padding(4)
                            .overlay {
                                if cell.id == nowCellId {
                                    Circle().strokeBorder(DS2.Color.accent, lineWidth: 2)
                                }
                            }
                        Text(cell.at.map { PlanEntrySummary.timeLabel(minutesOfDay($0)) } ?? "미정")
                            .font(DS2.Font.caption2)
                            .foregroundStyle(DS2.Color.textSecondary)
                        Text(cell.title)
                            .font(DS2.Font.caption2)
                            .foregroundStyle(DS2.Color.textSecondary)
                            .lineLimit(1)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(label(cell))
                }
            }
            .padding(.vertical, DS2.Spacing.xs)
        }
    }

    @ViewBuilder
    private func dot(_ cell: DayCell) -> some View {
        switch cell.kind {
        case .done:
            Circle().fill(tint(cell.activityType))
        case .planned:
            Circle().fill(DS2.Color.textSecondary.opacity(0.25))
        case .extra:
            // 시안 「끼어든 칸」 — 계획에 없던 것은 테두리로 구분한다.
            Circle().strokeBorder(tint(cell.activityType), lineWidth: 2)
        }
    }

    /// 활동 색 자산만 쓴다 — hex 하드코딩 금지.
    /// ⚠️ `default:` 를 쓰지 않는다 — 새 분류가 생기면 **여기가 컴파일 에러**로 걸린다(swift-conventions.md).
    private func tint(_ rawValue: String?) -> Color {
        guard let raw = rawValue, let type = Activity.ActivityType.known(rawValue: raw) else {
            return DS2.Color.accent
        }
        switch type.category {
        case .feeding: return DS2.Color.feeding
        case .sleep: return DS2.Color.sleep
        case .diaper: return DS2.Color.diaper
        case .health: return DS2.Color.bath        // 목욕·체온·투약이 한 버킷(기존 앱 분류 그대로)
        case .pumping: return DS2.Color.pumping
        case .unknown: return DS2.Color.accent     // 센티넬 — 색을 지어내지 않는다
        }
    }

    private func minutesOfDay(_ date: Date) -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    /// 🩸 보인다 ≠ 읽힌다 — 점만 있으면 VoiceOver 에겐 빈 화면이다.
    private func label(_ cell: DayCell) -> String {
        let time = cell.at.map { PlanEntrySummary.timeLabel(minutesOfDay($0)) } ?? "시각 미정"
        switch cell.kind {
        case .done: return "\(cell.title) \(time) 기록됨"
        case .planned: return "\(cell.title) \(time) 예정"
        case .extra: return "\(cell.title) \(time) 계획에 없던 기록"
        }
    }
}

import SwiftUI

// MARK: - 묶는 규칙

/// 목록을 방식별로 묶는 **순수 규칙**. 화면에서 떼어 내 테스트로 잠근다.
enum PlanEntryGrouping {

    struct Section: Identifiable, Hashable {
        var id: PlanSchedule.Kind { kind }
        let kind: PlanSchedule.Kind
        let entries: [DayPlan.Entry]
    }

    /// 시안 순서 — 첫 기록부터 주기 · 고정 시각 · 앞 일 뒤에.
    /// ⚠️ 손으로 적은 목록이다. 새 방식을 넣으면 여기에도 넣어야 하고,
    ///    잊으면 `testEveryPersistableKindGetsASection` 이 빨갛게 걸린다.
    /// ⛔ `.unknown`(forward-compat 센티넬)은 여기 없다 — 이 판이 그릴 수 없는 항목이라
    ///    묶이지 않는다. 오늘의 어떤 판도 그 kind 를 쓰지 않는다.
    private static let order: [PlanSchedule.Kind] = [.afterFirst, .fixedTimes, .afterEntry]

    static func sections(for plan: DayPlan) -> [Section] {
        order.compactMap { kind in
            let matched = plan.entries
                .filter { $0.schedule.kind == kind }
                .sorted { $0.order < $1.order }
            return matched.isEmpty ? nil : Section(kind: kind, entries: matched)
        }
    }
}

// MARK: - 줄 요약 문구

/// 목록 한 줄 아래 「언제 오는지」를 사람 말로 적는 **순수 규칙**.
/// 시트의 문구와 갈라지지 않도록 `intervalLabel` 은 여기 하나만 둔다(판정은 하나).
enum PlanEntrySummary {

    static func text(for entry: DayPlan.Entry, in plan: DayPlan) -> String {
        switch entry.schedule.kind {

        case .fixedTimes:
            let times = (entry.schedule.minutesOfDay ?? []).sorted().map(timeLabel)
            return times.isEmpty ? "시각이 아직 없어요" : "매일 " + times.joined(separator: " · ")

        case .afterFirst:
            let anchor = anchorName(entry.schedule.anchorType)
            let every = intervalLabel(entry.schedule.everyMinutes ?? 0)
            let count = entry.schedule.count ?? 0
            return "첫 \(anchor)부터 \(every) · 하루 \(count)번"

        case .afterEntry:
            // 🔙 가리키던 항목이 지워졌으면 이 칸은 영영 「미정」이다(DayPlanExpander).
            //    빈칸으로 두면 부모는 왜 안 오는지 알 수 없다 — 말로 알려 준다.
            guard let id = entry.schedule.afterEntryId,
                  let target = plan.entries.first(where: { $0.id == id }) else {
                return "앞 항목이 없어졌어요"
            }
            let offset = entry.schedule.offsetMinutes ?? 0
            return offset == 0 ? "\(target.title) 바로 뒤" : "\(target.title) \(offset)분 뒤"

        case .unknown:
            // 신버전이 만든 방식 — 이 판은 언제인지 모른다. 시각을 지어내지 않는다.
            return "이 버전에서는 볼 수 없는 방식이에요"
        }
    }

    /// 자정으로부터의 분 → "07:00". 벽시계 분이라 시간대를 타지 않는다.
    static func timeLabel(_ minutesOfDay: Int) -> String {
        String(format: "%02d:%02d", minutesOfDay / 60, minutesOfDay % 60)
    }

    static func intervalLabel(_ minutes: Int) -> String {
        if minutes % 60 == 0 { return "\(minutes / 60)시간마다" }
        if minutes < 60 { return "\(minutes)분마다" }
        return "\(minutes / 60)시간 \(minutes % 60)분마다"
    }

    private static func anchorName(_ rawValue: String?) -> String {
        guard let raw = rawValue, let type = Activity.ActivityType.known(rawValue: raw) else { return "기록" }
        return type.displayName
    }
}

// MARK: - 넣고 지우는 규칙

/// 시간표에 항목을 넣고 빼는 **순수 규칙**. 저장은 VM 이 한다.
enum PlanEntryMutation {

    /// Phase 1 은 시간표 한 벌이다 — 없으면 이 이름으로 만든다.
    static let defaultPlanName = "우리 하루"

    /// 새 항목이 받을 순서 — 늘 맨 뒤.
    static func nextOrder(in plan: DayPlan?) -> Int {
        ((plan?.entries.map(\.order).max()) ?? -1) + 1
    }

    /// 항목을 넣은 시간표. `plan` 이 nil 이면 기본 시간표를 새로 만든다.
    static func appending(_ entry: DayPlan.Entry, to plan: DayPlan?) -> DayPlan {
        guard var updated = plan else {
            return DayPlan(name: defaultPlanName, entries: [entry])
        }
        updated.entries.append(entry)
        return updated
    }

    /// 항목을 지운 시간표.
    /// ⛔ 지운 항목을 가리키던 칸은 **같이 지우지 않는다** — 부모가 시키지 않은 삭제다.
    ///    목록에 남아 「앞 항목이 없어졌어요」로 보이고, 부모가 직접 고치거나 지운다.
    /// ⛔ 마지막 하나를 지워도 시간표 자체는 남긴다 — 빈 화면에서 다시 넣을 수 있게.
    static func removing(_ ids: Set<String>, from plan: DayPlan) -> DayPlan {
        var updated = plan
        updated.entries.removeAll { ids.contains($0.id) }
        return updated
    }
}

// MARK: - 목록 화면

/// 짜 둔 시간표. 방식별로 묶어 보여주고, 넣고 지운다.
/// ⛔ 여기서 `NavigationStack` 을 새로 열지 않는다 — 설정에서 push 된다(swift-conventions.md).
/// ⛔ 연속 일수·완료율 분수·「지연」 배지 없음 — 시간표는 재촉하지 않는다(설계 §2 결정 6).
struct DayPlanListView: View {
    @Environment(AuthViewModel.self) private var authVM
    @Environment(BabyViewModel.self) private var babyVM

    @State private var vm = DayPlanViewModel()
    @State private var editing: PlanEntryDraft?
    /// 🔑 「못 불러왔다」와 「없다」는 다르다 — 모르는 채로 "없어요" 라고 말하지 않기 위한 구분.
    @State private var loadFailed = false

    /// 🔴 `currentUserId` 를 **먼저** 본다 — `dataUserId` 는 로그아웃 뒤에도
    ///    공유 아기의 소유자 uid 를 돌려준다(#49 결함군).
    private var ownerUserId: String? {
        guard let current = authVM.currentUserId else { return nil }
        return babyVM.dataUserId(currentUserId: current) ?? current
    }

    private var currentPlan: DayPlan? { vm.plans.first }
    private var allEntries: [DayPlan.Entry] { currentPlan?.entries ?? [] }

    private var subtitle: String {
        guard let name = babyVM.selectedBaby?.name, !name.isEmpty else {
            return "우리 집 하루를 미리 짜 둡니다"
        }
        return "\(KoreanParticle.withName(name)) 나의 하루를 짜 둡니다"
    }

    var body: some View {
        List {
            Section {
                Text(subtitle)
                    .font(DS2.Font.subheadline)
                    .foregroundStyle(DS2.Color.textSecondary)
                    .listRowBackground(Color.clear)
            }

            if loadFailed {
                Section {
                    ContentUnavailableView {
                        Label("시간표를 불러오지 못했어요", systemImage: "arrow.clockwise")
                    } description: {
                        Text("연결을 확인하고 다시 시도해 주세요. 짜 두신 것은 그대로 있습니다.")
                    } actions: {
                        Button("다시 시도") { Task { await reload() } }
                            .buttonStyle(.borderedProminent)
                            .tint(DS2.Color.accent)
                    }
                }
            } else if allEntries.isEmpty && !vm.isLoading {
                Section {
                    ContentUnavailableView(
                        "아직 짜 둔 것이 없어요",
                        systemImage: "calendar.day.timeline.left",
                        description: Text("분유·목욕·낮잠처럼 우리 집에서 반복되는 것을 넣어 두세요")
                    )
                }
            }

            if let plan = currentPlan {
                ForEach(PlanEntryGrouping.sections(for: plan)) { section in
                    Section {
                        ForEach(section.entries) { entry in
                            PlanEntryRow(entry: entry, plan: plan, tint: tint(section.kind))
                        }
                        .onDelete { offsets in
                            Task { await deleteEntries(offsets, in: section, of: plan) }
                        }
                    } header: {
                        Text(sectionTitle(section.kind))
                            .foregroundStyle(tint(section.kind))
                    }
                }
            }

            Section {
                addButtonRow
                footnote
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("우리 하루")
        .task { await reload() }
        .sheet(item: $editing) { draft in
            PlanEntrySheet(draft: draft, precedingEntries: allEntries) { saved in
                Task { await appendEntry(saved) }
            }
            // 🔙 나가는 길이 보여야 한다 — 시트엔 저장 버튼뿐이라
            //    쓸어내려 닫는 법을 모르면 막다른 길이 된다.
            .presentationDragIndicator(.visible)
        }
        .alert("문제가 생겼어요", isPresented: errorPresented) {
            Button("확인", role: .cancel) { vm.errorMessage = nil }
        } message: {
            Text(vm.errorMessage ?? "")
        }
    }

    // MARK: - 조각

    private var addButtonRow: some View {
        Button {
            editing = PlanEntryDraft(title: "", kind: .afterFirst)
        } label: {
            HStack(spacing: DS2.Spacing.sm) {
                Image(systemName: "plus")
                Text("시간표에 추가")
                Spacer()
            }
            .font(DS2.Font.callout)
            .foregroundStyle(DS2.Color.accent)
            .padding(.vertical, DS2.Spacing.xs)
            // 🩸 보인다 ≠ 쓸 수 있다 — `.buttonStyle(.plain)` 은 **글자가 있는 자리만** 눌린다.
            //    `Spacer()` 로 넓힌 오른쪽 절반이 죽어 있었다(줄 가운데를 눌러도 아무 일이 없었다).
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("눌러서 새 항목을 시간표에 넣습니다")
    }

    private var footnote: some View {
        Text("시간표는 밑그림입니다. 그 시각에 꼭 해야 하는 게 아니고, 늦었다고 알리지 않습니다.")
            .font(DS2.Font.caption)
            .foregroundStyle(DS2.Color.textSecondary)
            .listRowBackground(Color.clear)
    }

    private var errorPresented: Binding<Bool> {
        Binding(get: { vm.errorMessage != nil }, set: { if !$0 { vm.errorMessage = nil } })
    }

    /// ⚠️ `default:` 를 쓰지 않는다 — 네 번째 방식이 생기면 여기가 컴파일 에러로 걸린다.
    private func sectionTitle(_ kind: PlanSchedule.Kind) -> String {
        switch kind {
        case .afterFirst: "첫 기록부터 주기"
        case .fixedTimes: "고정 시각"
        case .afterEntry: "앞 일 뒤에 이어서"
        case .unknown: "이 버전에서는 볼 수 없는 것"
        }
    }

    private func tint(_ kind: PlanSchedule.Kind) -> Color {
        switch kind {
        case .afterFirst: DS2.Color.feeding
        case .fixedTimes: DS2.Color.bath
        case .afterEntry: DS2.Color.pumping
        case .unknown: DS2.Color.textSecondary
        }
    }

    // MARK: - 동작

    /// 불러오기 실패는 **화면 안에서** 말한다(경고창은 손님이 방금 한 일이 안 됐을 때만).
    /// 모달을 닫아도 「없어요」로 되돌아가지 않게, 실패 사실을 화면 상태로 남긴다.
    private func reload() async {
        guard let userId = ownerUserId else { return }
        await vm.load(userId: userId)
        loadFailed = vm.errorMessage != nil
        if loadFailed { vm.errorMessage = nil }
    }

    private func appendEntry(_ draft: PlanEntryDraft) async {
        guard let userId = ownerUserId,
              let entry = draft.build(order: PlanEntryMutation.nextOrder(in: currentPlan)) else { return }
        await vm.save(PlanEntryMutation.appending(entry, to: currentPlan), userId: userId)
    }

    private func deleteEntries(_ offsets: IndexSet, in section: PlanEntryGrouping.Section, of plan: DayPlan) async {
        guard let userId = ownerUserId else { return }
        let ids = Set(offsets.compactMap { section.entries.indices.contains($0) ? section.entries[$0].id : nil })
        guard !ids.isEmpty else { return }
        await vm.save(PlanEntryMutation.removing(ids, from: plan), userId: userId)
    }
}

// MARK: - 한 줄

private struct PlanEntryRow: View {
    let entry: DayPlan.Entry
    let plan: DayPlan
    let tint: Color

    private var icon: String {
        guard let raw = entry.activityType, let type = Activity.ActivityType.known(rawValue: raw) else {
            return "circle.dotted"
        }
        return type.icon
    }

    var body: some View {
        HStack(spacing: DS2.Spacing.md) {
            Image(systemName: icon)
                .font(DS2.Font.callout)
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: DS2.Radius.sm))

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(DS2.Font.headline)
                    .foregroundStyle(DS2.Color.textPrimary)
                Text(PlanEntrySummary.text(for: entry, in: plan))
                    .font(DS2.Font.caption)
                    .foregroundStyle(DS2.Color.textSecondary)
            }
            Spacer()
        }
        .padding(.vertical, DS2.Spacing.xs)
    }
}

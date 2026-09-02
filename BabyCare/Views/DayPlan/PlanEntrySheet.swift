import SwiftUI

// MARK: - PlanEntryDraft

/// 시트가 편집하는 값. 화면 상태가 아니라 **순수 값**이라 테스트로 잠근다.
struct PlanEntryDraft: Identifiable, Hashable {
    /// Task 6 이 `.sheet(item:)` 로 이 값을 띄운다 — 고정 id 하나가 그 계약이다.
    let id = UUID()

    var title: String
    var kind: PlanSchedule.Kind
    var lane: DayPlan.Lane = .baby
    var activityType: String?

    var minutesOfDay: [Int] = []
    var anchorType: String?
    var everyMinutes: Int?
    var count: Int?
    var afterEntryId: String?
    var offsetMinutes: Int?

    var isValid: Bool {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        switch kind {
        case .fixedTimes:
            return !minutesOfDay.isEmpty && minutesOfDay.allSatisfy { (0..<1440).contains($0) }
        case .afterFirst:
            guard let a = anchorType, !a.isEmpty else { return false }
            return (everyMinutes ?? 0) > 0 && (count ?? 0) > 0
        case .afterEntry:
            guard let e = afterEntryId, !e.isEmpty else { return false }
            return (offsetMinutes ?? -1) >= 0
        case .unknown:
            // 미지의 종류(forward-compat 센티넬, T1) — 부모가 고를 수 없고, 나타나도 유효하지 않다.
            return false
        }
    }

    func build(order: Int) -> DayPlan.Entry? {
        guard isValid else { return nil }
        let schedule: PlanSchedule
        switch kind {
        case .fixedTimes:
            schedule = .fixedTimes(minutesOfDay: minutesOfDay)
        case .afterFirst:
            schedule = .afterFirst(anchorType: anchorType ?? "", everyMinutes: everyMinutes ?? 0, count: count ?? 0)
        case .afterEntry:
            schedule = .afterEntry(entryId: afterEntryId ?? "", offsetMinutes: offsetMinutes ?? 0)
        case .unknown:
            // isValid 가 이미 false 라 여기 못 온다 — switch 전수성을 지키려고 남긴다.
            return nil
        }
        return DayPlan.Entry(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            activityType: activityType,
            lane: lane,
            schedule: schedule,
            order: order
        )
    }
}

// MARK: - PlanEntrySheet

/// 「언제」를 고르는 시트 — 세 방식(첫 기록부터 주기·고정 시각·앞 일 뒤에) 중 하나를 고르고
/// 그 방식의 입력을 채운다. 시각은 **부모가 정한 계획**일 뿐, 마감이 아니다(설계 §2 결정 6).
struct PlanEntrySheet: View {
    @State private var draft: PlanEntryDraft
    /// 「앞 일 뒤에」에서 고를 수 있는 앞 항목들(자기 자신 제외) — 호출부가 넘긴다.
    let precedingEntries: [DayPlan.Entry]
    let onSave: (PlanEntryDraft) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var isAddingFixedTime = false
    @State private var pendingFixedTime = Date()

    /// `.unknown`(forward-compat 센티넬)은 부모가 고를 수 있는 선택지가 아니다 — picker에 절대 노출 금지.
    private static let anchorTypeChoices: [Activity.ActivityType] =
        Activity.ActivityType.allCases.filter { $0 != .unknown }

    init(draft: PlanEntryDraft, precedingEntries: [DayPlan.Entry], onSave: @escaping (PlanEntryDraft) -> Void) {
        _draft = State(initialValue: draft)
        self.precedingEntries = precedingEntries
        self.onSave = onSave
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS2.Spacing.md) {
                header
                ForEach([PlanSchedule.Kind.afterFirst, .fixedTimes, .afterEntry], id: \.self) { kind in
                    kindCard(kind)          // 고른 것만 테두리 강조 · 안쪽에 그 방식의 입력
                }
                footnote                    // 「밑그림입니다」 안내
            }
            .padding(DS2.Spacing.lg)
        }
        .background(DS2.Color.surfacePrimary)
        .safeAreaInset(edge: .bottom) { saveBar }   // 하단 고정(전 폼 관례)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: DS2.Spacing.xs) {
            TextField("예: 분유, 목욕, 낮잠", text: $draft.title)
                .font(DS2.Font.title2)
                .foregroundStyle(DS2.Color.textPrimary)
            Text("아기에 맞는 방식으로 고르세요")
                .font(DS2.Font.subheadline)
                .foregroundStyle(DS2.Color.textSecondary)
        }
    }

    // MARK: - Cards

    @ViewBuilder
    private func kindCard(_ kind: PlanSchedule.Kind) -> some View {
        let isSelected = draft.kind == kind
        VStack(alignment: .leading, spacing: DS2.Spacing.sm) {
            Button {
                draft.kind = kind
            } label: {
                HStack(spacing: DS2.Spacing.sm) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(DS2.Font.title3)
                        .foregroundStyle(isSelected ? DS2.Color.accent : DS2.Color.textSecondary.opacity(0.4))
                    Text(kindTitle(kind))
                        .font(DS2.Font.headline)
                        .foregroundStyle(DS2.Color.textPrimary)
                    Spacer()
                }
            }
            .buttonStyle(.plain)

            Text(kindDescription(kind))
                .font(DS2.Font.callout)
                .foregroundStyle(DS2.Color.textSecondary)

            kindInputs(kind)
        }
        .padding(DS2.Spacing.lg)
        .background(DS2.Color.surfaceSecondary, in: RoundedRectangle(cornerRadius: DS2.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: DS2.Radius.md)
                .strokeBorder(
                    isSelected ? DS2.Color.accent : DS2.Color.textSecondary.opacity(0.2),
                    lineWidth: isSelected ? 2 : 1
                )
        )
        .ds2Shadow(.sm)
    }

    private func kindTitle(_ kind: PlanSchedule.Kind) -> String {
        switch kind {
        case .afterFirst: "첫 기록부터 주기"
        case .fixedTimes: "고정 시각"
        case .afterEntry: "앞 일 뒤에 이어서"
        case .unknown: ""   // 절대 노출 금지 — body 의 ForEach 가 이 kind 를 넘기지 않는다.
        }
    }

    private func kindDescription(_ kind: PlanSchedule.Kind) -> String {
        switch kind {
        case .afterFirst:
            "아기가 오늘 처음 기록된 시각을 기준으로 펼쳐집니다. 매일 하루가 다르게 시작하는 아기에게 맞아요."
        case .fixedTimes:
            "매일 같은 시각에 옵니다. 목욕·약·내 밥처럼 시계에 붙는 것에 맞아요."
        case .afterEntry:
            "시각이 아니라 순서가 뜻인 것입니다. 앞 항목이 끝나야 다음이 옵니다."
        case .unknown:
            ""
        }
    }

    @ViewBuilder
    private func kindInputs(_ kind: PlanSchedule.Kind) -> some View {
        switch kind {
        case .afterFirst: afterFirstInputs
        case .fixedTimes: fixedTimesInputs
        case .afterEntry: afterEntryInputs
        case .unknown: EmptyView()
        }
    }

    // MARK: - 첫 기록부터 주기

    private var afterFirstInputs: some View {
        VStack(alignment: .leading, spacing: DS2.Spacing.sm) {
            anchorTypeMenu
            Stepper(
                "주기: \(intervalLabel(everyMinutesBinding.wrappedValue))",
                value: everyMinutesBinding, in: 30...720, step: 30
            )
            .font(DS2.Font.callout)
            Stepper("하루 \(countBinding.wrappedValue)번", value: countBinding, in: 1...24)
                .font(DS2.Font.callout)
            if let times = afterFirstPreview {
                previewBox(times)
            }
        }
    }

    private var anchorTypeMenu: some View {
        Menu {
            ForEach(Self.anchorTypeChoices) { type in
                Button(type.displayName) { draft.anchorType = type.rawValue }
            }
        } label: {
            HStack(spacing: DS2.Spacing.xs) {
                Text(anchorTypeDisplayName)
                Image(systemName: "chevron.down").font(DS2.Font.caption2)
            }
            .font(DS2.Font.callout)
            .foregroundStyle(DS2.Color.accent)
            .padding(.horizontal, DS2.Spacing.sm)
            .padding(.vertical, DS2.Spacing.xs)
            .background(DS2.Color.tintPink, in: RoundedRectangle(cornerRadius: DS2.Radius.sm))
        }
    }

    private var anchorTypeDisplayName: String {
        guard let raw = draft.anchorType, let type = Activity.ActivityType.known(rawValue: raw) else {
            return "기록 종류 고르기"
        }
        return type.displayName
    }

    private var everyMinutesBinding: Binding<Int> {
        Binding(get: { draft.everyMinutes ?? 180 }, set: { draft.everyMinutes = $0 })
    }

    private var countBinding: Binding<Int> {
        Binding(get: { draft.count ?? 6 }, set: { draft.count = $0 })
    }

    private func intervalLabel(_ minutes: Int) -> String {
        if minutes % 60 == 0 { return "\(minutes / 60)시간마다" }
        if minutes < 60 { return "\(minutes)분마다" }
        return "\(minutes / 60)시간 \(minutes % 60)분마다"
    }

    /// 「첫 기록부터 주기」 미리보기 — 문구를 손으로 적지 말고 순수 함수에서 뽑는다.
    private func previewTimes(anchorHour: Int) -> [Date] {
        guard let entry = draft.build(order: 0) else { return [] }
        let cal = Calendar.current
        let day = cal.startOfDay(for: Date())
        let anchor = cal.date(byAdding: .minute, value: anchorHour * 60 + 20, to: day) ?? day
        let plan = DayPlan(id: "preview", name: "preview", entries: [entry])
        let anchors = DayAnchors(firstRecordByType: [draft.anchorType ?? "": anchor])
        return DayPlanExpander.slots(plan: plan, day: day, anchors: anchors, calendar: cal)
            .compactMap(\.plannedAt)
    }

    /// 예시 정박점(오전 6시대)으로 뽑은 미리보기 — 비어 있으면(아직 무효) 카드에 아무 것도 안 보여준다.
    private var afterFirstPreview: [Date]? {
        let times = previewTimes(anchorHour: 6)
        return times.isEmpty ? nil : times
    }

    private func previewBox(_ times: [Date]) -> some View {
        VStack(alignment: .leading, spacing: DS2.Spacing.xs) {
            Text("첫 기록이 \(DateFormatters.hourMinute.string(from: times[0]))이면")
                .font(DS2.Font.caption)
                .foregroundStyle(DS2.Color.textSecondary)
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 50), spacing: DS2.Spacing.xs)],
                alignment: .leading, spacing: DS2.Spacing.xs
            ) {
                ForEach(Array(times.enumerated()), id: \.offset) { index, date in
                    Text(DateFormatters.hourMinute.string(from: date))
                        .font(DS2.Font.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(index == 0 ? DS2.Color.textOnAccent : DS2.Color.accent)
                        .padding(.horizontal, DS2.Spacing.sm)
                        .padding(.vertical, DS2.Spacing.xs)
                        .background(
                            index == 0 ? DS2.Color.accent : DS2.Color.tintPink,
                            in: RoundedRectangle(cornerRadius: DS2.Radius.sm)
                        )
                }
            }
        }
        .padding(DS2.Spacing.md)
        .background(DS2.Color.surfacePrimary, in: RoundedRectangle(cornerRadius: DS2.Radius.sm))
    }

    // MARK: - 고정 시각

    private var fixedTimesInputs: some View {
        VStack(alignment: .leading, spacing: DS2.Spacing.sm) {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 60), spacing: DS2.Spacing.xs)],
                alignment: .leading, spacing: DS2.Spacing.xs
            ) {
                ForEach(draft.minutesOfDay, id: \.self) { minute in
                    Button {
                        draft.minutesOfDay.removeAll { $0 == minute }
                    } label: {
                        HStack(spacing: 4) {
                            Text(timeLabel(minute))
                            Image(systemName: "xmark")
                                .font(DS2.Font.caption2)
                        }
                        .font(DS2.Font.caption)
                        .foregroundStyle(DS2.Color.textPrimary)
                        .padding(.horizontal, DS2.Spacing.sm)
                        .padding(.vertical, DS2.Spacing.xs)
                        .background(DS2.Color.surfacePrimary, in: RoundedRectangle(cornerRadius: DS2.Radius.sm))
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    isAddingFixedTime = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("시각")
                    }
                    .font(DS2.Font.caption)
                    .foregroundStyle(DS2.Color.textSecondary)
                    .padding(.horizontal, DS2.Spacing.sm)
                    .padding(.vertical, DS2.Spacing.xs)
                    .overlay(
                        RoundedRectangle(cornerRadius: DS2.Radius.sm)
                            .strokeBorder(DS2.Color.textSecondary.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4]))
                    )
                }
                .buttonStyle(.plain)
            }

            if isAddingFixedTime {
                HStack(spacing: DS2.Spacing.sm) {
                    DatePicker("", selection: $pendingFixedTime, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                    Spacer()
                    Button("추가") { addPendingFixedTime() }
                        .font(DS2.Font.callout)
                    Button("취소") { isAddingFixedTime = false }
                        .font(DS2.Font.callout)
                        .foregroundStyle(DS2.Color.textSecondary)
                }
            }
        }
    }

    private func timeLabel(_ minute: Int) -> String {
        let base = Calendar.current.startOfDay(for: Date())
        let date = Calendar.current.date(byAdding: .minute, value: minute, to: base) ?? base
        return DateFormatters.hourMinute.string(from: date)
    }

    private func addPendingFixedTime() {
        let components = Calendar.current.dateComponents([.hour, .minute], from: pendingFixedTime)
        let minute = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        if !draft.minutesOfDay.contains(minute) {
            draft.minutesOfDay.append(minute)
            draft.minutesOfDay.sort()
        }
        isAddingFixedTime = false
    }

    // MARK: - 앞 일 뒤에 이어서

    @ViewBuilder
    private var afterEntryInputs: some View {
        VStack(alignment: .leading, spacing: DS2.Spacing.sm) {
            if precedingEntries.isEmpty {
                Text("아직 시간표에 앞에 놓을 항목이 없어요")
                    .font(DS2.Font.caption)
                    .foregroundStyle(DS2.Color.textSecondary)
            } else {
                afterEntryMenu
            }
            Stepper("\(offsetMinutesBinding.wrappedValue)분 뒤", value: offsetMinutesBinding, in: 0...240, step: 5)
                .font(DS2.Font.callout)
        }
    }

    private var afterEntryMenu: some View {
        Menu {
            ForEach(precedingEntries) { entry in
                Button(entry.title) { draft.afterEntryId = entry.id }
            }
        } label: {
            HStack(spacing: DS2.Spacing.xs) {
                Text(afterEntryDisplayName)
                Image(systemName: "chevron.down").font(DS2.Font.caption2)
            }
            .font(DS2.Font.callout)
            .foregroundStyle(DS2.Color.pumping)
            .padding(.horizontal, DS2.Spacing.sm)
            .padding(.vertical, DS2.Spacing.xs)
            .background(DS2.Color.tintPurple, in: RoundedRectangle(cornerRadius: DS2.Radius.sm))
        }
    }

    private var afterEntryDisplayName: String {
        guard let id = draft.afterEntryId, let entry = precedingEntries.first(where: { $0.id == id }) else {
            return "앞 항목 고르기"
        }
        return entry.title
    }

    private var offsetMinutesBinding: Binding<Int> {
        Binding(get: { draft.offsetMinutes ?? 30 }, set: { draft.offsetMinutes = $0 })
    }

    // MARK: - Footer

    private var footnote: some View {
        HStack(alignment: .top, spacing: DS2.Spacing.sm) {
            Image(systemName: "info.circle")
                .font(DS2.Font.caption)
                .foregroundStyle(DS2.Color.textSecondary)
            Text("시간표는 밑그림입니다. 그 시각에 꼭 해야 하는 게 아니고, 늦었다고 알리지 않습니다.")
                .font(DS2.Font.caption)
                .foregroundStyle(DS2.Color.textSecondary)
        }
    }

    private var saveBar: some View {
        Button {
            onSave(draft)
            dismiss()
        } label: {
            Text("시간표에 넣기").frame(maxWidth: .infinity)
        }
        .disabled(!draft.isValid)
        .buttonStyle(.borderedProminent)
        .tint(DS2.Color.accent)
        .padding(DS2.Spacing.lg)
    }
}

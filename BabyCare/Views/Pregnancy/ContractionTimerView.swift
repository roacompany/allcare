import SwiftUI

/// 진통 간격 타이머 (②기록 [상태별], 풀스크린). 5-1-1 규칙 안내 — **절대시간 기반**(타이머 카운트 의존 금지).
/// "병원 연락 고려"는 비지시적 안내일 뿐 — 의료 단정 금지.
@MainActor
struct ContractionTimerView: View {
    @Environment(PregnancyViewModel.self) private var pregnancyVM
    @Environment(AuthViewModel.self) private var authVM
    @Environment(\.dismiss) private var dismiss

    @State private var session: ContractionSession
    @State private var isContracting = false
    @State private var feedbackTrigger = 0

    init(pregnancyId: String) {
        _session = State(initialValue: ContractionSession(pregnancyId: pregnancyId))
    }

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                content(now: context.date)
            }
            .navigationTitle("진통 타이머")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("종료") { Task { await endSession() } }
                }
            }
            .sensoryFeedback(.impact, trigger: feedbackTrigger)
        }
        .interactiveDismissDisabled(true)   // 진행 중 실수 이탈 방지
    }

    @ViewBuilder private func content(now: Date) -> some View {
        ScrollView {
            VStack(spacing: DS2.Spacing.lg) {
                statusCard(now: now)
                bigToggleButton(now: now)
                Toggle("초산이에요", isOn: $session.isFirstBirth)
                    .tint(DS2.Color.pregnancy)
                    .padding(.horizontal, DS2.Spacing.xs)
                guidanceCaption
                if !session.contractions.isEmpty { recentList }
                disclaimer
            }
            .padding(DS2.Spacing.lg)
        }
    }

    // MARK: - 5-1-1 상태

    private func statusCard(now: Date) -> some View {
        let met = session.meets511(asOf: now)
        return DS2Card(tint: met ? DS2.Color.pregnancy : nil) {
            VStack(spacing: DS2.Spacing.sm) {
                Text(met ? "5-1-1 기준에 도달했어요" : "진통을 기록해 주세요")
                    .font(DS2.Font.headline)
                    .foregroundStyle(met ? DS2.Color.pregnancy : DS2.Color.textPrimary)
                if met {
                    Text("병원 연락을 고려해 보세요. 최종 판단은 담당 의료진과 함께 하세요.")
                        .font(DS2.Font.caption).foregroundStyle(DS2.Color.textSecondary)
                        .multilineTextAlignment(.center)
                }
                HStack(spacing: DS2.Spacing.xl) {
                    metric("기록", "\(session.contractions.count)회")
                    metric("마지막 간격", lastIntervalText)
                    metric("마지막 지속", lastDurationText(now: now))
                }
            }
        }
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(DS2.Font.title3).foregroundStyle(DS2.Color.textPrimary)
            Text(title).font(DS2.Font.caption2).foregroundStyle(DS2.Color.textSecondary)
        }
    }

    // MARK: - 시작/끝 버튼

    private func bigToggleButton(now: Date) -> some View {
        Button {
            if isContracting { endContraction() } else { startContraction() }
        } label: {
            Text(isContracting ? "수축 끝" : "수축 시작")
                .font(DS2.Font.title2)
                .foregroundStyle(DS2.Color.textOnAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS2.Spacing.xl)
                .background(isContracting ? DS2.Color.warning : DS2.Color.pregnancy,
                            in: RoundedRectangle(cornerRadius: DS2.Radius.lg))
        }
        .buttonStyle(.plain)
    }

    private var guidanceCaption: some View {
        Text("5-1-1 규칙: 5분 간격 · 1분 지속이 1시간 지속되면 알려드려요. (초산·경산에 따라 다를 수 있어요.)")
            .font(DS2.Font.caption2).foregroundStyle(DS2.Color.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 최근 기록

    private var recentList: some View {
        DS2Card {
            VStack(alignment: .leading, spacing: DS2.Spacing.sm) {
                Text("최근 수축").font(DS2.Font.headline).foregroundStyle(DS2.Color.textPrimary)
                ForEach(session.contractions.suffix(6).reversed()) { c in
                    HStack {
                        Text(c.startedAt, style: .time)
                            .font(DS2.Font.subheadline).foregroundStyle(DS2.Color.textPrimary)
                        Spacer()
                        if let d = c.durationSeconds {
                            Text("\(Int(d))초").font(DS2.Font.caption).foregroundStyle(DS2.Color.textSecondary)
                        } else {
                            Text("진행 중").font(DS2.Font.caption).foregroundStyle(DS2.Color.warning)
                        }
                    }
                }
            }
        }
    }

    private var disclaimer: some View {
        HStack(spacing: DS2.Spacing.sm) {
            Image(systemName: "info.circle.fill").foregroundStyle(DS2.Color.warning)
            Text("진통 간격은 참고용이에요. 통증·출혈·양막 파열 등은 즉시 의료진에게 연락하세요.")
                .font(DS2.Font.caption2).foregroundStyle(DS2.Color.textSecondary)
            Spacer(minLength: 0)
        }
        .padding(DS2.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS2.Color.warning.opacity(0.12), in: RoundedRectangle(cornerRadius: DS2.Radius.sm))
    }

    // MARK: - Helpers

    private var lastIntervalText: String {
        let sorted = session.contractions.sorted { $0.startedAt < $1.startedAt }
        guard sorted.count >= 2 else { return "—" }
        let interval = sorted[sorted.count - 1].startedAt.timeIntervalSince(sorted[sorted.count - 2].startedAt)
        return "\(Int(interval / 60))분 \(Int(interval.truncatingRemainder(dividingBy: 60)))초"
    }

    private func lastDurationText(now: Date) -> String {
        guard let last = session.contractions.last else { return "—" }
        if let d = last.durationSeconds { return "\(Int(d))초" }
        // 진행 중: 절대시간 기준 경과
        return "\(Int(now.timeIntervalSince(last.startedAt)))초"
    }

    // MARK: - Actions (절대시간 기록)

    private func startContraction() {
        session.contractions.append(ContractionEvent(startedAt: Date()))
        isContracting = true
        feedbackTrigger += 1
        Task { await persist() }
    }

    private func endContraction() {
        if let idx = session.contractions.indices.last {
            session.contractions[idx].endedAt = Date()
        }
        isContracting = false
        feedbackTrigger += 1
        Task { await persist() }
    }

    private func endSession() async {
        session.endedAt = Date()
        await persist()
        dismiss()
    }

    private func persist() async {
        guard let userId = authVM.currentUserId else { return }
        await pregnancyVM.saveContractionSession(session, userId: userId)
    }
}

#if DEBUG
#Preview {
    let vm = PregnancyViewModel()
    vm.activePregnancy = Pregnancy(lmpDate: nil, dueDate: nil, fetusCount: 1, babyNickname: "둘째")
    return ContractionTimerView(pregnancyId: "p1")
        .environment(vm).environment(AuthViewModel()).tint(DS2.Color.pregnancy)
}
#endif

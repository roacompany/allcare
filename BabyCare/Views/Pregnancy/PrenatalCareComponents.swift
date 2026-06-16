import SwiftUI

// MARK: - 면책 배너 (③검진 §섹션 0)

/// 검진 탭 의료 면책 — 라일락 톤 1줄(보라 0.12 배경 + 0.4 stroke). safety.md: 의학 단정 금지.
struct PrenatalDisclaimerBanner: View {
    var body: some View {
        HStack(spacing: DS2.Spacing.sm) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(DS2.Color.pregnancy)
            Text("검진 일정과 수치는 참고용이에요. 의학적 판단은 담당 의료진과 함께 하세요.")
                .font(DS2.Font.caption)
                .foregroundStyle(DS2.Color.textPrimary)
            Spacer(minLength: 0)
        }
        .padding(DS2.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS2.Color.pregnancy.opacity(0.12), in: RoundedRectangle(cornerRadius: DS2.Radius.sm))
        .overlay(
            RoundedRectangle(cornerRadius: DS2.Radius.sm)
                .stroke(DS2.Color.pregnancy.opacity(0.4), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}

// MARK: - 다음 검진 히어로 카드 (③검진 §섹션 1)

/// 다음(또는 가장 임박한 지연) 검진을 D-day 캡슐로 강조 + 이번 주 권장 검진 칩 + [완료] CTA.
/// 검진 0건이면 빈 상태 + [검진 추가]. D-day 규칙은 PrenatalVisit 로직 재사용.
struct NextVisitHeroCard: View {
    let visit: PrenatalVisit?
    let recommendedItem: KoreanPrenatalScheduleItem?
    let onAdd: () -> Void
    let onToggleComplete: () -> Void

    var body: some View {
        DS2Card(tint: DS2.Color.pregnancy) {
            if let visit {
                filled(visit)
            } else {
                empty
            }
        }
    }

    @ViewBuilder private func filled(_ visit: PrenatalVisit) -> some View {
        VStack(alignment: .leading, spacing: DS2.Spacing.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: DS2.Spacing.xs) {
                    Text("다음 검진")
                        .font(DS2.Font.caption).foregroundStyle(DS2.Color.textSecondary)
                    Text(Self.visitTypeLabel(visit.visitType))
                        .font(DS2.Font.title3).foregroundStyle(DS2.Color.textPrimary)
                    if let hospital = visit.hospitalName, !hospital.isEmpty {
                        Text(hospital).font(DS2.Font.caption).foregroundStyle(DS2.Color.textSecondary)
                    }
                    Text(visit.scheduledAt, format: .dateTime.year().month().day().weekday(.short))
                        .font(DS2.Font.caption).foregroundStyle(DS2.Color.textSecondary)
                }
                Spacer(minLength: DS2.Spacing.sm)
                dDayCapsule(visit)
            }
            if let rec = recommendedItem {
                Label("이번 주 권장: \(rec.title)", systemImage: "stethoscope")
                    .font(DS2.Font.caption2)
                    .padding(.horizontal, DS2.Spacing.sm).padding(.vertical, DS2.Spacing.xs)
                    .background(DS2.Color.pregnancy.opacity(0.14), in: Capsule())
                    .foregroundStyle(DS2.Color.pregnancy)
            }
            Button(action: onToggleComplete) {
                Label(visit.isCompleted ? "완료 취소" : "완료 체크",
                      systemImage: visit.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(DS2.Font.subheadline)
            }
            .buttonStyle(.bordered)
            .tint(DS2.Color.pregnancy)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("다음 검진, \(Self.visitTypeLabel(visit.visitType)), \(Self.dDayText(visit))")
    }

    private var empty: some View {
        VStack(spacing: DS2.Spacing.md) {
            Image(systemName: "stethoscope")
                .font(.largeTitle).foregroundStyle(DS2.Color.pregnancy.opacity(0.6))
            Text("아직 등록된 검진이 없어요").font(DS2.Font.headline)
            Text("첫 산전 진찰 일정을 추가해보세요")
                .font(DS2.Font.caption).foregroundStyle(DS2.Color.textSecondary)
            Button(action: onAdd) {
                Label("검진 추가", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .tint(DS2.Color.pregnancy)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS2.Spacing.sm)
    }

    private func dDayCapsule(_ visit: PrenatalVisit) -> some View {
        let color = Self.dDayColor(visit)
        return Text(Self.dDayText(visit))
            .font(DS2.Font.subheadline).bold()
            .padding(.horizontal, DS2.Spacing.md).padding(.vertical, DS2.Spacing.sm)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }

    static func dDayText(_ visit: PrenatalVisit) -> String {
        if visit.isCompleted { return "완료" }
        let d = visit.daysUntilScheduled
        if d == 0 { return "오늘" }
        if d > 0 { return "D-\(d)" }
        return "D+\(-d) 지연"
    }

    static func dDayColor(_ visit: PrenatalVisit) -> Color {
        if visit.isCompleted { return .green }
        if visit.isOverdue { return .red }
        if visit.isDueSoon { return .orange }
        if visit.daysUntilScheduled == 0 { return DS2.Color.pregnancy }
        return DS2.Color.textSecondary
    }

    static func visitTypeLabel(_ type: String?) -> String {
        switch type {
        case "routine": return "정기 검진"
        case "ultrasound": return "초음파"
        case "bloodTest": return "혈액검사"
        case "gtt": return "당부하검사"
        default: return "산전 진찰"
        }
    }
}

// MARK: - 한국 산전검진 타임라인 (③검진 §섹션 2, 🔴 핵심)

/// 한국 표준 산전검진 일정을 현재 주차에 맞춰 자동 매핑한 세로 타임라인.
/// 데이터는 `KoreanPrenatalSchedule`(의료감수 전 초안·참고용). 노드 탭 → 검진 추가(프리필).
struct KoreanPrenatalTimelineCard: View {
    let currentWeek: Int?
    var onSelect: ((KoreanPrenatalScheduleItem) -> Void)?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(currentWeek: Int?, onSelect: ((KoreanPrenatalScheduleItem) -> Void)? = nil) {
        self.currentWeek = currentWeek
        self.onSelect = onSelect
    }

    private var nodes: [PrenatalTimelineNode] {
        KoreanPrenatalSchedule.timeline(currentWeek: currentWeek)
    }

    var body: some View {
        DS2Card(tint: DS2.Color.pregnancy) {
            VStack(alignment: .leading, spacing: DS2.Spacing.md) {
                header
                VStack(alignment: .leading, spacing: DS2.Spacing.lg) {
                    ForEach(nodes) { node in
                        if let onSelect {
                            Button { onSelect(node.item) } label: {
                                PrenatalScheduleNodeRow(node: node, reduceMotion: reduceMotion, tappable: true)
                            }
                            .buttonStyle(.plain)
                        } else {
                            PrenatalScheduleNodeRow(node: node, reduceMotion: reduceMotion, tappable: false)
                        }
                    }
                }
                Divider()
                Text(KoreanPrenatalSchedule.checkupIntervalNote)
                    .font(DS2.Font.caption2)
                    .foregroundStyle(DS2.Color.textSecondary)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DS2.Spacing.xs) {
            Text("한국 산전검진 일정")
                .font(DS2.Font.headline)
                .foregroundStyle(DS2.Color.textPrimary)
            Text(currentWeek != nil
                 ? "내 주차에 맞춰 자동으로 알려드려요"
                 : "임신 주차를 등록하면 내 일정에 맞춰 표시돼요")
                .font(DS2.Font.caption)
                .foregroundStyle(DS2.Color.textSecondary)
        }
    }
}

/// 타임라인 노드 1행 — 상태 점(지난/지금/예정 3상태) + 제목 + 주차범위 + 요약 + 보조노트.
struct PrenatalScheduleNodeRow: View {
    let node: PrenatalTimelineNode
    let reduceMotion: Bool
    var tappable: Bool = false
    @State private var pulse = false

    private var item: KoreanPrenatalScheduleItem { node.item }
    private var status: PrenatalScheduleStatus { node.status }

    var body: some View {
        HStack(alignment: .top, spacing: DS2.Spacing.md) {
            statusDot
                .padding(.top, 3)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: DS2.Spacing.sm) {
                    Text(item.title)
                        .font(DS2.Font.subheadline)
                        .foregroundStyle(status == .future ? DS2.Color.textSecondary : DS2.Color.textPrimary)
                    if status == .current {
                        Text("지금 여기")
                            .font(DS2.Font.caption2).bold()
                            .padding(.horizontal, DS2.Spacing.sm)
                            .padding(.vertical, 2)
                            .background(DS2.Color.pregnancy.opacity(0.18), in: Capsule())
                            .foregroundStyle(DS2.Color.pregnancy)
                    }
                }
                Text("\(item.weekStart)~\(item.weekEnd)주 · \(item.summary)")
                    .font(DS2.Font.caption)
                    .foregroundStyle(DS2.Color.textSecondary)
                if let note = item.note {
                    Text(note)
                        .font(DS2.Font.caption2)
                        .foregroundStyle(DS2.Color.textSecondary.opacity(0.8))
                }
            }
            Spacer(minLength: 0)
            if tappable {
                Image(systemName: "plus.circle")
                    .font(.caption)
                    .foregroundStyle(DS2.Color.pregnancy.opacity(0.7))
                    .padding(.top, 2)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.title), \(item.weekStart)~\(item.weekEnd)주, \(statusLabel)")
        .accessibilityHint(tappable ? "두 번 탭하면 이 검진을 추가해요" : "")
    }

    @ViewBuilder private var statusDot: some View {
        switch status {
        case .current:
            Circle()
                .fill(DS2.Color.pregnancy)
                .frame(width: 12, height: 12)
                .scaleEffect((pulse && !reduceMotion) ? 1.25 : 1.0)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulse)
                .onAppear { if !reduceMotion { pulse = true } }
        case .past:
            Circle()
                .fill(DS2.Color.textSecondary.opacity(0.4))
                .frame(width: 12, height: 12)
        case .future:
            Circle()
                .strokeBorder(DS2.Color.pregnancy.opacity(0.4), lineWidth: 1.5)
                .frame(width: 12, height: 12)
        }
    }

    private var statusLabel: String {
        switch status {
        case .past: return "지난 권장 시기"
        case .current: return "지금 권장 시기"
        case .future: return "다가올 시기"
        }
    }
}

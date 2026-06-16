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

// MARK: - 한국 산전검진 타임라인 (③검진 §섹션 2, 🔴 핵심)

/// 한국 표준 산전검진 일정을 현재 주차에 맞춰 자동 매핑한 세로 타임라인.
/// 데이터는 `KoreanPrenatalSchedule`(의료감수 전 초안·참고용). 검진 객체 연동(완료/누락)은 후속 Phase.
struct KoreanPrenatalTimelineCard: View {
    let currentWeek: Int?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var nodes: [PrenatalTimelineNode] {
        KoreanPrenatalSchedule.timeline(currentWeek: currentWeek)
    }

    var body: some View {
        DS2Card(tint: DS2.Color.pregnancy) {
            VStack(alignment: .leading, spacing: DS2.Spacing.md) {
                header
                VStack(alignment: .leading, spacing: DS2.Spacing.lg) {
                    ForEach(nodes) { node in
                        PrenatalScheduleNodeRow(node: node, reduceMotion: reduceMotion)
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
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.title), \(item.weekStart)~\(item.weekEnd)주, \(statusLabel)")
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

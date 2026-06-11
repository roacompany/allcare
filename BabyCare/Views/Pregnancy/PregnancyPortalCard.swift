import SwiftUI

// MARK: - PregnancyPortalCard

/// `.both` 케이스에서 육아 홈 최상단에 삽입될 임신 노트 진입 카드.
///
/// "🤰 임신 N주 · D-NN ›" 포맷으로 현재 임신 상태를 표시하고
/// `onTap` 클로저를 통해 임신 노트 fullScreenCover를 열도록 Part B에서 배선.
///
/// DashboardPregnancyHomeCard의 데이터 접근 패턴을 미러링하며,
/// 보라 액센트(DS2.Color.pregnancy)로 육아 핑크와 시각 분리.
///
/// - 배선(Part B): ContentView에서 `.fullScreenCover`로 PregnancyNoteRootView를 제시하고
///   `onTap`에 해당 sheet present action을 전달.
/// - ContentView는 이 태스크에서 **수정하지 않음**.
@MainActor
struct PregnancyPortalCard: View {
    // MARK: - Init

    /// 카드 탭 시 호출. Part B에서 fullScreenCover present action으로 배선.
    let onTap: () -> Void

    // MARK: - Environment

    @Environment(PregnancyViewModel.self) private var pregnancyVM

    // MARK: - Body

    var body: some View {
        Button(action: onTap) {
            cardContent
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Card Content

    private var cardContent: some View {
        HStack(spacing: DS2.Spacing.md) {
            pregnancyIconBadge

            VStack(alignment: .leading, spacing: DS2.Spacing.xs) {
                titleRow
                subtitleRow
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(DS2.Color.pregnancy.opacity(0.5))
        }
        .padding(DS2.Spacing.lg)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: DS2.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS2.Radius.md, style: .continuous)
                .stroke(DS2.Color.pregnancy.opacity(0.25), lineWidth: 1)
        )
        .ds2Shadow(.sm)
    }

    // MARK: - Icon Badge

    private var pregnancyIconBadge: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DS2.Radius.sm, style: .continuous)
                .fill(DS2.Color.pregnancy.opacity(0.12))
                .frame(width: 48, height: 48)
            Image(systemName: "figure.and.child.holdinghands")
                .font(.title2)
                .foregroundStyle(DS2.Color.pregnancy)
        }
    }

    // MARK: - Title Row

    private var titleRow: some View {
        HStack(spacing: DS2.Spacing.sm) {
            weekLabel
            dDayBadge
        }
    }

    private var weekLabel: some View {
        Group {
            if let wd = pregnancyVM.currentWeekAndDay {
                Text("🤰 임신 \(wd.weeks)주")
                    .font(DS2.Font.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(DS2.Color.textPrimary)
            } else {
                Text("🤰 임신 중")
                    .font(DS2.Font.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(DS2.Color.textPrimary)
            }
        }
    }

    private var dDayBadge: some View {
        Group {
            if let dDay = pregnancyVM.dDay {
                let (label, bgColor) = dDayBadgeContent(dDay: dDay)
                Text(label)
                    .font(DS2.Font.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(DS2.Color.textOnAccent)
                    .padding(.horizontal, DS2.Spacing.sm)
                    .padding(.vertical, DS2.Spacing.xs)
                    .background(bgColor)
                    .clipShape(Capsule())
            }
        }
    }

    private func dDayBadgeContent(dDay: Int) -> (String, Color) {
        if dDay > 0 {
            return ("D-\(dDay)", DS2.Color.pregnancy)
        } else if dDay == 0 {
            return ("오늘!", DS2.Color.pregnancy)
        } else {
            return ("D+\(-dDay)", DS2.Color.warning)
        }
    }

    // MARK: - Subtitle Row

    private var subtitleRow: some View {
        Group {
            if let visit = nextUpcomingVisit {
                let days = visit.daysUntilScheduled
                HStack(spacing: DS2.Spacing.xs) {
                    Image(systemName: "stethoscope")
                        .font(.caption2)
                        .foregroundStyle(DS2.Color.pregnancy.opacity(0.7))
                    Text(days == 0 ? "산전 방문 오늘" : "산전 방문 \(days)일 후")
                        .font(DS2.Font.caption)
                        .foregroundStyle(DS2.Color.textSecondary)
                }
            } else {
                Text("임신 노트 열기")
                    .font(DS2.Font.caption)
                    .foregroundStyle(DS2.Color.pregnancy.opacity(0.7))
            }
        }
    }

    // MARK: - Accessibility

    private var accessibilityLabel: String {
        var parts: [String] = []
        if let wd = pregnancyVM.currentWeekAndDay {
            parts.append("임신 \(wd.weeks)주 \(wd.days)일")
        }
        if let dDay = pregnancyVM.dDay {
            if dDay > 0 {
                parts.append("출산까지 D-\(dDay)")
            } else if dDay == 0 {
                parts.append("오늘이 출산 예정일")
            } else {
                parts.append("예정일 경과 \(-dDay)일")
            }
        }
        parts.append("임신 노트 열기")
        return parts.joined(separator: ", ")
    }

    // MARK: - Helpers

    private var nextUpcomingVisit: PrenatalVisit? {
        pregnancyVM.prenatalVisits
            .filter { !$0.isCompleted && $0.daysUntilScheduled >= 0 }
            .sorted { $0.scheduledAt < $1.scheduledAt }
            .first
    }
}

// MARK: - Preview

#if DEBUG
#Preview("D-112 예시") {
    let vm = PregnancyViewModel()
    vm.activePregnancy = Pregnancy(
        lmpDate: Calendar.current.date(byAdding: .day, value: -168, to: Date()),
        dueDate: Calendar.current.date(byAdding: .day, value: 112, to: Date()),
        fetusCount: 1,
        babyNickname: "둘째"
    )
    return ScrollView {
        PregnancyPortalCard(onTap: {})
            .padding(.horizontal, DS2.Spacing.lg)
    }
    .environment(vm)
}

#Preview("예정일 미설정") {
    let vm = PregnancyViewModel()
    vm.activePregnancy = Pregnancy(
        lmpDate: nil,
        dueDate: nil,
        fetusCount: 1,
        babyNickname: "아기"
    )
    return ScrollView {
        PregnancyPortalCard(onTap: {})
            .padding(.horizontal, DS2.Spacing.lg)
    }
    .environment(vm)
}
#endif

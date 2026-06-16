import SwiftUI

// MARK: - Sticky 헤더

/// NN주N일 · D-day · 40주 진행바 (SCREENS.md §①여정 1).
struct JourneyStickyHeader: View {
    let weekAndDay: (weeks: Int, days: Int)?
    let dDay: Int?

    private var progress: Double {
        guard let w = weekAndDay?.weeks else { return 0 }
        return min(Double(w) / 40.0, 1.0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS2.Spacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text(weekAndDay.map { "임신 \($0.weeks)주 \($0.days)일" } ?? "임신 중")
                    .font(DS2.Font.title3)
                    .foregroundStyle(DS2.Color.textPrimary)
                Spacer()
                dDayLabel
            }
            ProgressView(value: progress)
                .tint(DS2.Color.pregnancy)
        }
        .padding(DS2.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
    }

    @ViewBuilder private var dDayLabel: some View {
        if let dDay {
            if dDay > 0 {
                Text("D-\(dDay)").font(DS2.Font.headline).foregroundStyle(DS2.Color.pregnancy)
            } else if dDay == 0 {
                Text("오늘이 예정일").font(DS2.Font.subheadline).foregroundStyle(DS2.Color.pregnancy)
            } else {
                Text("+\(-dDay)일 경과").font(DS2.Font.subheadline).foregroundStyle(DS2.Color.warning)
            }
        } else {
            Text("예정일 미설정").font(DS2.Font.caption).foregroundStyle(DS2.Color.textSecondary)
        }
    }
}

// MARK: - 데일리팁

struct DailyTipCard: View {
    let tip: String
    var body: some View {
        DS2Card(tint: DS2.Color.pregnancy) {
            HStack(alignment: .top, spacing: DS2.Spacing.sm) {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(DS2.Color.pregnancy)
                Text(tip)
                    .font(DS2.Font.subheadline)
                    .foregroundStyle(DS2.Color.textPrimary)
                Spacer(minLength: 0)
            }
        }
    }
}

// MARK: - 아기 크기 비교

struct BabySizeCompareCard: View {
    let week: Int
    let fruitSize: String
    let milestone: String
    var body: some View {
        DS2Card {
            HStack(spacing: DS2.Spacing.md) {
                Image(systemName: "leaf.fill")
                    .font(.title2)
                    .foregroundStyle(DS2.Color.pregnancy)
                VStack(alignment: .leading, spacing: DS2.Spacing.xs) {
                    Text("\(week)주차 · \(fruitSize) 크기")
                        .font(DS2.Font.headline)
                        .foregroundStyle(DS2.Color.textPrimary)
                    Text(milestone)
                        .font(DS2.Font.caption)
                        .foregroundStyle(DS2.Color.textSecondary)
                }
                Spacer(minLength: 0)
            }
        }
    }
}

// MARK: - QuickLogStrip (태동/증상/체중)

/// 1탭 시 해당 기록 시트를 여는 가로 칩 3개. 동작은 부모(여정)가 클로저로 주입.
struct JourneyQuickLogStrip: View {
    let onKick: () -> Void
    let onSymptom: () -> Void
    let onWeight: () -> Void

    var body: some View {
        ViewThatFits {
            HStack(spacing: DS2.Spacing.sm) { chips }
            VStack(spacing: DS2.Spacing.sm) { chips }  // a11y XXXL 폴백
        }
    }

    @ViewBuilder private var chips: some View {
        quickChip("태동", "hand.tap.fill", onKick)
        quickChip("증상", "note.text", onSymptom)
        quickChip("체중", "scalemass.fill", onWeight)
    }

    private func quickChip(_ title: String, _ icon: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: DS2.Spacing.xs) {
                Image(systemName: icon)
                Text(title).font(DS2.Font.subheadline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS2.Spacing.md)
            .background(DS2.Color.tintPurple.opacity(0.5), in: RoundedRectangle(cornerRadius: DS2.Radius.sm))
            .foregroundStyle(DS2.Color.pregnancy)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title) 기록하기")
    }
}

// MARK: - 동적 승격 카드

struct JourneyPromotedCardView: View {
    let card: JourneyPromotedCard
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS2.Spacing.md) {
                Image(systemName: symbol).font(.title2).foregroundStyle(DS2.Color.pregnancy)
                VStack(alignment: .leading, spacing: DS2.Spacing.xs) {
                    Text(title).font(DS2.Font.headline).foregroundStyle(DS2.Color.textPrimary)
                    Text(subtitle).font(DS2.Font.caption).foregroundStyle(DS2.Color.textSecondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
            .padding(DS2.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: DS2.Radius.md))
        }
        .buttonStyle(.plain)
    }

    private var symbol: String {
        switch card {
        case .upcomingVisit: return "stethoscope"
        case .laborTimer: return "timer"
        }
    }
    private var title: String {
        switch card {
        case .upcomingVisit: return "다가오는 산전검진"
        case .laborTimer: return "진통 간격 타이머"
        }
    }
    private var subtitle: String {
        switch card {
        case let .upcomingVisit(days, hospital):
            let d = days == 0 ? "오늘" : "D-\(days)"
            return [hospital, d].compactMap { $0 }.joined(separator: " · ")
        case .laborTimer:
            return "5-1-1 규칙으로 진통 간격을 기록하세요"
        }
    }
}

// MARK: - 미완 체크리스트 top-3

struct ChecklistPreviewCard: View {
    let items: [PregnancyChecklistItem]
    let onSeeAll: () -> Void

    var body: some View {
        DS2Card {
            VStack(alignment: .leading, spacing: DS2.Spacing.md) {
                HStack {
                    Label("산전 체크리스트", systemImage: "checklist")
                        .font(DS2.Font.headline)
                        .foregroundStyle(DS2.Color.textPrimary)
                    Spacer()
                    Button("전체보기", action: onSeeAll)
                        .font(DS2.Font.caption)
                        .foregroundStyle(DS2.Color.pregnancy)
                }
                ForEach(items) { item in
                    HStack(spacing: DS2.Spacing.sm) {
                        Image(systemName: "circle").foregroundStyle(DS2.Color.pregnancy.opacity(0.5))
                        Text(item.title).font(DS2.Font.subheadline).foregroundStyle(DS2.Color.textPrimary)
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }
}

// MARK: - 미래 검진 마일스톤

struct VisitMilestoneList: View {
    let milestones: [PrenatalMilestone]
    var body: some View {
        DS2Card {
            VStack(alignment: .leading, spacing: DS2.Spacing.md) {
                Label("다가올 산전검진", systemImage: "calendar")
                    .font(DS2.Font.headline)
                    .foregroundStyle(DS2.Color.textPrimary)
                ForEach(milestones) { m in
                    HStack(spacing: DS2.Spacing.sm) {
                        Image(systemName: m.symbol).foregroundStyle(DS2.Color.pregnancy)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(m.title).font(DS2.Font.subheadline).foregroundStyle(DS2.Color.textPrimary)
                            Text("\(m.weekRange.lowerBound)~\(m.weekRange.upperBound)주")
                                .font(DS2.Font.caption).foregroundStyle(DS2.Color.textSecondary)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }
}

// MARK: - 의료 면책

struct JourneyDisclaimerBanner: View {
    let multiFetus: Bool
    var body: some View {
        VStack(spacing: DS2.Spacing.sm) {
            banner(icon: "info.circle.fill", tint: DS2.Color.warning,
                   text: "이 정보는 일반적인 참고 자료이며 의학적 진단을 대체하지 않습니다.")
            if multiFetus {
                banner(icon: "exclamationmark.triangle.fill", tint: DS2.Color.pregnancy,
                       text: "단태아 기준 정보입니다. 다태임신은 담당 의료진과 상의하세요.")
            }
        }
    }
    private func banner(icon: String, tint: Color, text: String) -> some View {
        HStack(spacing: DS2.Spacing.sm) {
            Image(systemName: icon).foregroundStyle(tint)
            Text(text).font(DS2.Font.caption).foregroundStyle(DS2.Color.textPrimary)
            Spacer(minLength: 0)
        }
        .padding(DS2.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: DS2.Radius.sm))
    }
}

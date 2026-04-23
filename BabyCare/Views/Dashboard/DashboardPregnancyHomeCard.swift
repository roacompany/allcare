import SwiftUI

/// 홈 대시보드 스크롤에 삽입되는 임신 요약 카드.
/// `.both` 또는 `.pregnancyOnly` AppContext에서만 노출.
/// baby UI를 대체하지 않고 스크롤 중간에 추가(additive)로 삽입.
/// 탭 시 DashboardPregnancyView(상세)로 내비게이션.
struct DashboardPregnancyHomeCard: View {
    @Environment(PregnancyViewModel.self) private var pregnancyVM

    var body: some View {
        NavigationLink {
            DashboardPregnancyView()
        } label: {
            cardContent
        }
        .buttonStyle(.plain)
    }

    // MARK: - Card Content

    private var cardContent: some View {
        HStack(spacing: 14) {
            pregnancyIconBadge

            VStack(alignment: .leading, spacing: 6) {
                titleRow
                detailRow
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppColors.primaryAccent.opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: - Icon Badge

    private var pregnancyIconBadge: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(AppColors.primaryAccent.opacity(0.15))
                .frame(width: 48, height: 48)
            Image(systemName: "figure.maternity")
                .font(.title2)
                .foregroundStyle(AppColors.primaryAccent)
        }
    }

    // MARK: - Title Row

    private var titleRow: some View {
        HStack(spacing: 8) {
            weekLabel
            dDayBadge
        }
    }

    private var weekLabel: some View {
        Group {
            if let wd = pregnancyVM.currentWeekAndDay {
                Text("임신 \(wd.weeks)주 \(wd.days)일")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
            } else {
                Text("임신 중")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
            }
        }
    }

    private var dDayBadge: some View {
        Group {
            if let dDay = pregnancyVM.dDay {
                let (label, color) = dDayBadgeContent(dDay: dDay)
                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(color)
                    .clipShape(Capsule())
            }
        }
    }

    private func dDayBadgeContent(dDay: Int) -> (String, Color) {
        if dDay > 0 {
            return ("D-\(dDay)", AppColors.primaryAccent)
        } else if dDay == 0 {
            return ("오늘!", AppColors.primaryAccent)
        } else {
            return ("D+\(-dDay)", AppColors.warmOrangeColor)
        }
    }

    // MARK: - Detail Row

    private var detailRow: some View {
        HStack(spacing: 12) {
            nextVisitLabel
            weightDeltaLabel
        }
    }

    private var nextVisitLabel: some View {
        Group {
            if let visit = nextUpcomingVisit {
                let days = visit.daysUntilScheduled
                HStack(spacing: 4) {
                    Image(systemName: "stethoscope")
                        .font(.caption2)
                        .foregroundStyle(AppColors.indigoColor)
                    if days == 0 {
                        Text("산전 방문 오늘")
                    } else {
                        Text("산전 방문 \(days)일 후")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    private var weightDeltaLabel: some View {
        Group {
            if let delta = weightDelta {
                let sign = delta >= 0 ? "+" : ""
                HStack(spacing: 4) {
                    Image(systemName: "scalemass")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("\(sign)\(String(format: "%.1f", delta))kg")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Helpers

    private var nextUpcomingVisit: PrenatalVisit? {
        pregnancyVM.prenatalVisits
            .filter { !$0.isCompleted && $0.daysUntilScheduled >= 0 }
            .sorted { $0.scheduledAt < $1.scheduledAt }
            .first
    }

    private var weightDelta: Double? {
        guard
            let baseline = pregnancyVM.activePregnancy?.prePregnancyWeight,
            let latest = pregnancyVM.weightEntries
                .sorted(by: { $0.measuredAt > $1.measuredAt })
                .first
        else { return nil }
        // 단위 통일: lb → kg 변환 (1 lb = 0.453592 kg)
        let latestKg = (latest.unit == "lb") ? latest.weight * 0.453_592 : latest.weight
        return latestKg - baseline
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    let vm = PregnancyViewModel()
    vm.activePregnancy = Pregnancy(
        lmpDate: Calendar.current.date(byAdding: .day, value: -84, to: Date()),
        dueDate: Calendar.current.date(byAdding: .day, value: 196, to: Date()),
        fetusCount: 1,
        babyNickname: "테스트"
    )
    return ScrollView {
        DashboardPregnancyHomeCard()
            .padding(.horizontal, 16)
    }
    .environment(vm)
}
#endif

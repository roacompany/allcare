import SwiftUI

// MARK: - Pregnancy Week Info

private struct PregnancyWeekInfo: Codable {
    let week: Int
    let fruitSize: String
    let milestone: String
    let tip: String
    let disclaimerKey: String?
}

// MARK: - DashboardPregnancyView

struct DashboardPregnancyView: View {
    @Environment(PregnancyViewModel.self) private var pregnancyVM
    @Environment(AuthViewModel.self) private var authVM

    @State private var showTransitionSheet = false

    private var weekInfos: [PregnancyWeekInfo] = {
        guard let url = Bundle.main.url(forResource: "pregnancy-weeks", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let infos = try? JSONDecoder().decode([PregnancyWeekInfo].self, from: data) else {
            return []
        }
        return infos
    }()

    private var currentWeekInfo: PregnancyWeekInfo? {
        guard let wd = pregnancyVM.currentWeekAndDay else { return nil }
        let currentWeek = wd.weeks
        // 현재 주차보다 크거나 같은 가장 가까운 항목 매칭
        return weekInfos.last(where: { $0.week <= currentWeek }) ?? weekInfos.first
    }

    private var incompletedChecklistPreview: [PregnancyChecklistItem] {
        Array(pregnancyVM.checklistItems.filter { !$0.isCompleted }.prefix(3))
    }

    private var nextDueSoonVisit: PrenatalVisit? {
        pregnancyVM.prenatalVisits
            .filter { $0.isDueSoon }
            .sorted { $0.scheduledAt < $1.scheduledAt }
            .first
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    disclaimerBanner

                    dDayCard

                    // 출산 CTA 배너 (예정일 설정 시 항상 노출)
                    if pregnancyVM.dDay != nil {
                        birthCTABanner
                    }

                    if let pregnancy = pregnancyVM.activePregnancy {
                        weekProgressCard(pregnancy: pregnancy)

                        if (pregnancy.fetusCount ?? 1) > 1 {
                            multiFetusDisclaimer
                        }
                    }

                    if !incompletedChecklistPreview.isEmpty {
                        checklistPreviewCard
                    }

                    if let visit = nextDueSoonVisit {
                        nextVisitCard(visit: visit)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("임신 \(pregnancyVM.currentWeekAndDay.map { "\($0.weeks)주" } ?? "")")
                        .font(.headline)
                }
            }
            .sheet(isPresented: $showTransitionSheet) {
                if let pregnancy = pregnancyVM.activePregnancy {
                    PregnancyTransitionSheet(pregnancy: pregnancy)
                }
            }
        }
    }

    // MARK: - Birth CTA Banner

    private var birthCTABanner: some View {
        Button {
            showTransitionSheet = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "heart.circle.fill")
                    .font(.title2)
                    .foregroundStyle(AppColors.primaryAccent)

                VStack(alignment: .leading, spacing: 2) {
                    Text("출산했어요!")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("아기 정보를 등록하고 육아 모드로 전환하세요.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(AppColors.primaryAccent.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppColors.primaryAccent.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Disclaimer Banner

    private var disclaimerBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(.orange)
            Text("이 정보는 일반적인 참고 자료이며 의학적 진단을 대체하지 않습니다.")
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.orange.opacity(0.4), lineWidth: 1))
    }

    // MARK: - D-Day Card

    private var dDayCard: some View {
        VStack(spacing: 6) {
            if let dDay = pregnancyVM.dDay {
                if dDay > 0 {
                    Text("출산까지")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("D-\(dDay)")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.primaryAccent)
                    Text("일 남았어요")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else if dDay == 0 {
                    Text("오늘이 출산 예정일이에요!")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(AppColors.primaryAccent)
                        .multilineTextAlignment(.center)
                } else {
                    Text("예정일 경과")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("+\(-dDay)")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.warmOrangeColor)
                    Text("일")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                Image(systemName: "calendar.badge.exclamationmark")
                    .font(.largeTitle)
                    .foregroundStyle(AppColors.primaryAccent.opacity(0.5))
                Text("예정일 미설정")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.secondary)
                Text("임신 정보에서 예정일을 설정하세요")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Week Progress Card

    private func weekProgressCard(pregnancy: Pregnancy) -> some View {
        let wd = pregnancyVM.currentWeekAndDay
        let currentWeek = wd?.weeks ?? 0
        let progress = min(Double(currentWeek) / 40.0, 1.0)
        let info = currentWeekInfo

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("40주 중 \(currentWeek)주차")
                        .font(.headline)
                    if let days = wd?.days {
                        Text("\(days)일째")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if let fruit = info?.fruitSize {
                    VStack(spacing: 2) {
                        Image(systemName: "leaf.fill")
                            .font(.title2)
                            .foregroundStyle(AppColors.sageColor)
                        Text(fruit)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(AppColors.sageColor)
                    }
                }
            }

            ProgressView(value: progress)
                .tint(AppColors.primaryAccent)

            if let milestone = info?.milestone {
                Label(milestone, systemImage: "heart.fill")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let tip = info?.tip {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                        .padding(.top, 2)
                    Text(tip)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(10)
                .background(.yellow.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(16)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Multi-Fetus Disclaimer

    private var multiFetusDisclaimer: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.purple)
            Text("단태아 기준 정보입니다. 다태임신은 담당 의료진과 상의하세요.")
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.purple.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.purple.opacity(0.4), lineWidth: 1))
    }

    // MARK: - Checklist Preview Card

    private var checklistPreviewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("산전 체크리스트", systemImage: "checklist")
                    .font(.headline)
                Spacer()
                NavigationLink {
                    PregnancyChecklistView()
                } label: {
                    Text("전체보기")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppColors.primaryAccent)
                }
            }

            ForEach(incompletedChecklistPreview) { item in
                HStack(spacing: 10) {
                    Image(systemName: "circle")
                        .font(.body)
                        .foregroundStyle(AppColors.primaryAccent.opacity(0.5))
                    Text(item.title)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                }
            }
        }
        .padding(16)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Next Visit Card

    private func nextVisitCard(visit: PrenatalVisit) -> some View {
        NavigationLink {
            PrenatalVisitListView()
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppColors.indigoColor.opacity(0.2))
                        .frame(width: 50, height: 50)
                    Image(systemName: "stethoscope")
                        .font(.title2)
                        .foregroundStyle(AppColors.indigoColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("다음 산전 방문")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(visit.hospitalName ?? "병원 미지정")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    let days = visit.daysUntilScheduled
                    if days == 0 {
                        Text("오늘")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AppColors.indigoColor)
                            .clipShape(Capsule())
                    } else {
                        Text("D-\(days)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AppColors.indigoColor)
                            .clipShape(Capsule())
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(16)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

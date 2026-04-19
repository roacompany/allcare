import SwiftUI

struct HealthPregnancyView: View {
    @Environment(PregnancyViewModel.self) private var pregnancyVM
    @Environment(AuthViewModel.self) private var authVM

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // 면책 배너
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
                    .padding(.horizontal)

                    VStack(spacing: 12) {
                        // 태동 기록
                        NavigationLink {
                            KickSessionView()
                        } label: {
                            HealthPregnancySectionCard(
                                icon: "hand.tap.fill",
                                iconColor: AppColors.primaryAccent,
                                title: "태동 기록",
                                subtitle: kickSessionSubtitle
                            )
                        }
                        .buttonStyle(.plain)

                        // 산전 방문
                        NavigationLink {
                            PrenatalVisitListView()
                        } label: {
                            HealthPregnancySectionCard(
                                icon: "stethoscope",
                                iconColor: AppColors.indigoColor,
                                title: "산전 방문",
                                subtitle: prenatalVisitSubtitle,
                                badge: dueSoonBadge,
                                badgeColor: .blue
                            )
                        }
                        .buttonStyle(.plain)

                        // 체중 추이
                        NavigationLink {
                            PregnancyWeightView()
                        } label: {
                            HealthPregnancySectionCard(
                                icon: "scalemass.fill",
                                iconColor: AppColors.sageColor,
                                title: "체중 추이",
                                subtitle: weightSubtitle
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("임신 건강")
        }
    }

    private var kickSessionSubtitle: String {
        let count = pregnancyVM.kickSessions.count
        if count == 0 { return "태동을 기록해보세요 (ACOG 10회 목표)" }
        return "총 \(count)회 기록"
    }

    private var prenatalVisitSubtitle: String {
        let total = pregnancyVM.prenatalVisits.count
        if total == 0 { return "산전 방문 일정을 추가해보세요" }
        let upcoming = pregnancyVM.prenatalVisits.filter { $0.isDueSoon }.count
        if upcoming > 0 { return "예정 방문 \(upcoming)건" }
        return "총 \(total)건 기록"
    }

    private var dueSoonBadge: String? {
        let count = pregnancyVM.prenatalVisits.filter { $0.isDueSoon }.count
        return count > 0 ? "\(count) 예정" : nil
    }

    private var weightSubtitle: String {
        let count = pregnancyVM.weightEntries.count
        if count == 0 { return "체중을 기록해보세요" }
        if let last = pregnancyVM.weightEntries.sorted(by: { $0.measuredAt > $1.measuredAt }).first {
            return "최근: \(String(format: "%.1f", last.weight))\(last.unit)"
        }
        return "총 \(count)건 기록"
    }
}

// MARK: - Health Pregnancy Section Card

private struct HealthPregnancySectionCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    var badge: String? = nil
    var badgeColor: Color = .blue

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(iconColor.opacity(0.2))
                    .frame(width: 50, height: 50)
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(iconColor)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 8) {
                if let badge {
                    Text(badge)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(badgeColor)
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
}

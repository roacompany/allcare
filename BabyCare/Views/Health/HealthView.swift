import SwiftUI

struct HealthView: View {
    @Environment(HealthViewModel.self) private var healthVM
    @Environment(BabyViewModel.self) private var babyVM
    @Environment(AuthViewModel.self) private var authVM

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Alert Banners
                    if !healthVM.overdueVaccinations.isEmpty {
                        AlertBanner(
                            icon: "exclamationmark.triangle.fill",
                            message: "접종 지연 \(healthVM.overdueVaccinations.count)건이 있습니다",
                            color: .red
                        )
                    }

                    if !healthVM.upcomingVaccinations.isEmpty {
                        AlertBanner(
                            icon: "clock.fill",
                            message: "30일 이내 예방접종 \(healthVM.upcomingVaccinations.count)건",
                            color: .orange
                        )
                    }

                    // Section Cards
                    VStack(spacing: 12) {
                        // 예방접종
                        NavigationLink {
                            VaccinationListView()
                        } label: {
                            HealthSectionCard(
                                icon: "syringe.fill",
                                iconColor: Color(hex: "FF9FB5"),
                                title: "예방접종",
                                subtitle: vaccinationSubtitle,
                                badge: healthVM.overdueVaccinations.isEmpty ? nil : "\(healthVM.overdueVaccinations.count) 지연",
                                badgeColor: .red
                            )
                        }
                        .buttonStyle(.plain)

                        // 성장기록
                        NavigationLink {
                            GrowthView()
                        } label: {
                            HealthSectionCard(
                                icon: "chart.line.uptrend.xyaxis",
                                iconColor: Color(hex: "9FB5FF"),
                                title: "성장기록",
                                subtitle: "키, 몸무게, 머리둘레",
                                badge: nil,
                                badgeColor: .clear
                            )
                        }
                        .buttonStyle(.plain)

                        // 발달이정표
                        NavigationLink {
                            MilestoneListView()
                        } label: {
                            HealthSectionCard(
                                icon: "star.fill",
                                iconColor: Color(hex: "FFD59F"),
                                title: "발달이정표",
                                subtitle: milestoneSubtitle,
                                badge: nil,
                                badgeColor: .clear
                            )
                        }
                        .buttonStyle(.plain)

                        // 일기
                        NavigationLink {
                            DiaryView()
                        } label: {
                            HealthSectionCard(
                                icon: "book.fill",
                                iconColor: Color(hex: "9FDFBF"),
                                title: "일기",
                                subtitle: "아기의 하루를 기록해보세요",
                                badge: nil,
                                badgeColor: .clear
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("건강")
            .task {
                guard let userId = authVM.currentUserId,
                      let baby = babyVM.selectedBaby else { return }
                await healthVM.loadAll(userId: userId, babyId: baby.id)
                await healthVM.generateScheduleIfNeeded(
                    babyId: baby.id,
                    birthDate: baby.birthDate,
                    userId: userId
                )
            }
        }
    }

    private var vaccinationSubtitle: String {
        let completed = healthVM.completedVaccinations.count
        let total = healthVM.vaccinations.count
        if total == 0 { return "접종 기록 없음" }
        return "\(completed)/\(total) 접종 완료"
    }

    private var milestoneSubtitle: String {
        let achieved = healthVM.achievedMilestones.count
        let total = healthVM.milestones.count
        if total == 0 { return "이정표 없음" }
        return "\(achieved)/\(total) 달성"
    }
}

// MARK: - Alert Banner

private struct AlertBanner: View {
    let icon: String
    let message: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(message)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(color)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(color.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
}

// MARK: - Health Section Card

private struct HealthSectionCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let badge: String?
    let badgeColor: Color

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(iconColor.opacity(0.2))
                    .frame(width: 50, height: 50)
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(iconColor)
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

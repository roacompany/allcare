import SwiftUI

struct MilestoneListView: View {
    @Environment(HealthViewModel.self) private var healthVM
    @Environment(AuthViewModel.self) private var authVM
    @Environment(BabyViewModel.self) private var babyVM

    @State private var selectedMilestone: Milestone?
    @State private var filterMode: FilterMode = .all

    enum FilterMode: String, CaseIterable {
        case all = "전체"
        case current = "현재 시기"
        case overdue = "지연"
        case achieved = "달성"
    }

    private var babyAgeMonths: Int {
        guard let baby = babyVM.selectedBaby else { return 0 }
        let months = Calendar.current.dateComponents([.month], from: baby.birthDate, to: Date()).month ?? 0
        return max(0, months)
    }

    var body: some View {
        List {
            // 현재 아기 나이 + 진행률 요약
            ageSummarySection

            // 필터 피커
            Picker("필터", selection: $filterMode) {
                ForEach(FilterMode.allCases, id: \.self) { mode in
                    Text(filterLabel(mode)).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .listRowSeparator(.hidden)

            // 카테고리별 섹션
            ForEach(Milestone.MilestoneCategory.allCases, id: \.self) { category in
                let items = filteredMilestones(for: category)
                if !items.isEmpty {
                    Section {
                        CategoryProgressBar(
                            category: category,
                            achieved: allMilestones(for: category).filter(\.isAchieved).count,
                            total: allMilestones(for: category).count
                        )
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowSeparator(.hidden)

                        ForEach(items) { milestone in
                            MilestoneRow(milestone: milestone, babyAgeMonths: babyAgeMonths)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedMilestone = milestone
                                }
                        }
                    } header: {
                        HStack(spacing: 6) {
                            Image(systemName: category.icon)
                            Text(category.displayName)
                        }
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("발달이정표")
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $selectedMilestone) { ms in
            MilestoneDetailSheet(milestone: ms, babyAgeMonths: babyAgeMonths) { achievedDate in
                guard let userId = authVM.currentUserId else { return }
                Task {
                    await healthVM.toggleMilestone(ms, userId: userId, achievedDate: achievedDate)
                }
            }
        }
        .alert("오류", isPresented: Binding(
            get: { healthVM.errorMessage != nil },
            set: { if !$0 { healthVM.errorMessage = nil } }
        )) {
            Button("확인") { healthVM.errorMessage = nil }
        } message: {
            Text(healthVM.errorMessage ?? "")
        }
    }

    // MARK: - Age Summary

    private var ageSummarySection: some View {
        let total = healthVM.milestones.count
        let achieved = healthVM.achievedMilestones.count
        let overdue = healthVM.milestones.filter { !$0.isAchieved && ($0.expectedAgeMonths ?? 99) < babyAgeMonths }.count

        return VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    if let baby = babyVM.selectedBaby {
                        Text("\(baby.name) · 생후 \(babyAgeMonths)개월")
                            .font(.headline)
                    }
                    Text("\(achieved)/\(total) 달성")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if overdue > 0 {
                    Text("확인 필요 \(overdue)건")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(.orange))
                }
            }

            // 전체 진행 바
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.15))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppColors.successColor)
                        .frame(width: total > 0 ? geo.size.width * Double(achieved) / Double(total) : 0, height: 8)
                        .animation(.easeInOut(duration: 0.4), value: achieved)
                }
            }
            .frame(height: 8)
        }
        .padding(.vertical, 4)
        .listRowSeparator(.hidden)
    }

    // MARK: - Helpers

    private func allMilestones(for category: Milestone.MilestoneCategory) -> [Milestone] {
        healthVM.milestones
            .filter { $0.category == category }
            .sorted { ($0.expectedAgeMonths ?? 0) < ($1.expectedAgeMonths ?? 0) }
    }

    private func filteredMilestones(for category: Milestone.MilestoneCategory) -> [Milestone] {
        let all = allMilestones(for: category)
        switch filterMode {
        case .all:
            return all
        case .current:
            // 현재 나이 ±3개월
            return all.filter { ms in
                guard let m = ms.expectedAgeMonths, !ms.isAchieved else { return false }
                return m >= max(0, babyAgeMonths - 3) && m <= babyAgeMonths + 3
            }
        case .overdue:
            return all.filter { ms in
                !ms.isAchieved && (ms.expectedAgeMonths ?? 99) < babyAgeMonths
            }
        case .achieved:
            return all.filter(\.isAchieved)
        }
    }

    private func filterLabel(_ mode: FilterMode) -> String {
        switch mode {
        case .all: return "전체"
        case .current: return "현재"
        case .overdue:
            let count = healthVM.milestones.filter { !$0.isAchieved && ($0.expectedAgeMonths ?? 99) < babyAgeMonths }.count
            return count > 0 ? "지연 \(count)" : "지연"
        case .achieved: return "달성"
        }
    }
}

// MARK: - Category Progress Bar

private struct CategoryProgressBar: View {
    let category: Milestone.MilestoneCategory
    let achieved: Int
    let total: Int

    private var progress: Double {
        total == 0 ? 0 : Double(achieved) / Double(total)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(achieved)/\(total) 달성")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(String(format: "%.0f%%", progress * 100))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(progressColor)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(progressColor)
                        .frame(width: geo.size.width * progress, height: 6)
                        .animation(.easeInOut(duration: 0.4), value: progress)
                }
            }
            .frame(height: 6)
        }
    }

    private var progressColor: Color {
        switch category {
        case .motor: AppColors.feedingColor
        case .cognitive: AppColors.sleepColor
        case .language: AppColors.diaperColor
        case .social: AppColors.healthColor
        case .selfCare: AppColors.medicationColor
        }
    }
}

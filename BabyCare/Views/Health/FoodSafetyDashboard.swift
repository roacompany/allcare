import SwiftUI

// MARK: - FoodSafetyDashboard
// 식품 안전 분류 대시보드 (Safe / Caution / Forbidden 3-section 그리드)
// 기록 기반 분류 · 참고용 — 의학적 판단이 아닙니다.

struct FoodSafetyDashboard: View {
    @Environment(HealthViewModel.self) private var healthVM

    @State private var selectedEntry: FoodSafetyEntry?

    private var safeEntries: [FoodSafetyEntry] {
        healthVM.foodSafetyEntries.filter { $0.status == .safe }
    }

    private var cautionEntries: [FoodSafetyEntry] {
        healthVM.foodSafetyEntries.filter { $0.status == .caution }
    }

    private var forbiddenEntries: [FoodSafetyEntry] {
        healthVM.foodSafetyEntries.filter { $0.status == .forbidden }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                disclaimerBanner

                if healthVM.foodSafetyEntries.isEmpty {
                    emptyState
                } else {
                    if !forbiddenEntries.isEmpty {
                        foodSection(
                            title: NSLocalizedString("food.safety.section.forbidden", comment: ""),
                            entries: forbiddenEntries,
                            status: .forbidden
                        )
                    }
                    if !cautionEntries.isEmpty {
                        foodSection(
                            title: NSLocalizedString("food.safety.section.caution", comment: ""),
                            entries: cautionEntries,
                            status: .caution
                        )
                    }
                    if !safeEntries.isEmpty {
                        foodSection(
                            title: NSLocalizedString("food.safety.section.safe", comment: ""),
                            entries: safeEntries,
                            status: .safe
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .navigationTitle(NSLocalizedString("food.safety.dashboard.title", comment: ""))
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $selectedEntry) { entry in
            FoodHistorySheet(entry: entry)
                .environment(healthVM)
        }
    }

    // MARK: - Disclaimer

    private var disclaimerBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(AppColors.indigoColor)
                .font(.subheadline)
            Text(NSLocalizedString("food.safety.disclaimer", comment: ""))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.indigoColor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.top, 8)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "fork.knife.circle")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(NSLocalizedString("food.safety.empty.title", comment: ""))
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(NSLocalizedString("food.safety.empty.message", comment: ""))
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Food Section

    private func foodSection(
        title: String,
        entries: [FoodSafetyEntry],
        status: FoodSafetyStatus
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: status.icon)
                    .foregroundStyle(Color(status.colorName))
                    .font(.subheadline)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(status.colorName))
                Spacer()
                Text("\(entries.count)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 10) {
                ForEach(entries) { entry in
                    FoodTile(entry: entry)
                        .onTapGesture { selectedEntry = entry }
                }
            }
        }
    }
}

// MARK: - FoodTile

private struct FoodTile: View {
    let entry: FoodSafetyEntry

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: entry.status.icon)
                .font(.title3)
                .foregroundStyle(Color(entry.status.colorName))

            Text(entry.foodName)
                .font(.caption.weight(.medium))
                .lineLimit(2)
                .multilineTextAlignment(.center)

            if entry.trialCount > 0 {
                Text(String(format: NSLocalizedString("food.safety.tile.trialCount", comment: ""), entry.trialCount))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(Color(entry.status.colorName).opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(entry.status.colorName).opacity(0.2), lineWidth: 1)
        )
    }
}

import SwiftUI

struct MilestoneListView: View {
    @Environment(HealthViewModel.self) private var healthVM
    @Environment(AuthViewModel.self) private var authVM
    @Environment(BabyViewModel.self) private var babyVM

    @State private var selectedMilestone: Milestone?
    @State private var showDetailSheet = false

    var body: some View {
        List {
            ForEach(Milestone.MilestoneCategory.allCases, id: \.self) { category in
                let items = milestones(for: category)
                if !items.isEmpty {
                    Section {
                        CategoryProgressBar(
                            category: category,
                            achieved: items.filter(\.isAchieved).count,
                            total: items.count
                        )
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowSeparator(.hidden)

                        ForEach(items) { milestone in
                            MilestoneRow(milestone: milestone)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedMilestone = milestone
                                    showDetailSheet = true
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
        .sheet(isPresented: $showDetailSheet) {
            if let ms = selectedMilestone {
                MilestoneDetailSheet(milestone: ms) { achievedDate in
                    guard let userId = authVM.currentUserId else { return }
                    Task {
                        await healthVM.toggleMilestone(ms, userId: userId)
                        // If we're marking achieved with a specific date, update it
                        if let date = achievedDate, !ms.isAchieved {
                            if let idx = healthVM.milestones.firstIndex(where: { $0.id == ms.id }) {
                                var updated = healthVM.milestones[idx]
                                updated.achievedDate = date
                                healthVM.milestones[idx] = updated
                                try? await FirestoreService.shared.saveMilestone(updated, userId: userId)
                            }
                        }
                    }
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

    private func milestones(for category: Milestone.MilestoneCategory) -> [Milestone] {
        healthVM.milestones
            .filter { $0.category == category }
            .sorted { ($0.expectedAgeMonths ?? 0) < ($1.expectedAgeMonths ?? 0) }
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
        case .motor: Color(hex: "FF9FB5")
        case .cognitive: Color(hex: "9FB5FF")
        case .language: Color(hex: "FFD59F")
        case .social: Color(hex: "9FDFBF")
        case .selfCare: Color(hex: "D59FFF")
        }
    }
}

// MARK: - Milestone Row

private struct MilestoneRow: View {
    let milestone: Milestone

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: milestone.isAchieved ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(milestone.isAchieved ? Color(hex: "4CAF50") : Color.secondary)
                .font(.title3)

            VStack(alignment: .leading, spacing: 4) {
                Text(milestone.title)
                    .font(.subheadline.weight(.medium))
                    .strikethrough(milestone.isAchieved, color: .secondary)
                    .foregroundStyle(milestone.isAchieved ? .secondary : .primary)

                if let months = milestone.expectedAgeMonths {
                    Text("기대 발달 시기: 생후 \(months)개월")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if milestone.isAchieved, let date = milestone.achievedDate {
                    Text("달성일: \(DateFormatters.shortDate.string(from: date))")
                        .font(.caption)
                        .foregroundStyle(Color(hex: "4CAF50"))
                }
            }

            Spacer()

            if milestone.isAchieved {
                Image(systemName: "star.fill")
                    .font(.caption)
                    .foregroundStyle(Color(hex: "FFD59F"))
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Milestone Detail Sheet

private struct MilestoneDetailSheet: View {
    let milestone: Milestone
    let onToggle: (Date?) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var achievedDate = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section("이정표 정보") {
                    HStack {
                        Image(systemName: milestone.category.icon)
                            .foregroundStyle(.secondary)
                        Text(milestone.category.displayName)
                            .foregroundStyle(.secondary)
                    }

                    Text(milestone.title)
                        .font(.headline)

                    if let months = milestone.expectedAgeMonths {
                        HStack {
                            Text("기대 시기")
                            Spacer()
                            Text("생후 \(months)개월")
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let desc = milestone.description {
                        Text(desc)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if !milestone.isAchieved {
                    Section("달성일") {
                        DatePicker(
                            "달성한 날짜",
                            selection: $achievedDate,
                            in: ...Date(),
                            displayedComponents: .date
                        )
                        .environment(\.locale, Locale(identifier: "ko_KR"))
                    }
                } else {
                    if let date = milestone.achievedDate {
                        Section {
                            HStack {
                                Text("달성일")
                                Spacer()
                                Text(DateFormatters.shortDate.string(from: date))
                                    .foregroundStyle(Color(hex: "4CAF50"))
                            }
                        }
                    }
                }
            }
            .navigationTitle(milestone.isAchieved ? "달성 취소" : "달성 기록")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(milestone.isAchieved ? "달성 취소" : "달성") {
                        onToggle(milestone.isAchieved ? nil : achievedDate)
                        dismiss()
                    }
                    .foregroundStyle(milestone.isAchieved ? .red : Color(hex: "4CAF50"))
                }
            }
        }
    }
}

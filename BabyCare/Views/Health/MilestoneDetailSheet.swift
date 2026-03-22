import SwiftUI

// MARK: - Milestone Detail Sheet

struct MilestoneDetailSheet: View {
    let milestone: Milestone
    let babyAgeMonths: Int
    let onToggle: (Date?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var achievedDate = Date()

    private var isOverdue: Bool {
        !milestone.isAchieved && (milestone.expectedAgeMonths ?? 99) < babyAgeMonths
    }

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
                            if isOverdue {
                                Text("(지연)")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }

                    if let desc = milestone.description {
                        Text(desc)
                            .font(.subheadline)
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
                    Section("달성일 수정") {
                        DatePicker(
                            "달성한 날짜",
                            selection: $achievedDate,
                            in: ...Date(),
                            displayedComponents: .date
                        )
                        .environment(\.locale, Locale(identifier: "ko_KR"))
                    }
                }
            }
            .navigationTitle(milestone.isAchieved ? "달성 기록 수정" : "달성 기록")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if milestone.isAchieved {
                        Menu {
                            Button("날짜 저장") {
                                onToggle(achievedDate)
                                dismiss()
                            }
                            Button("달성 취소", role: .destructive) {
                                onToggle(nil)
                                dismiss()
                            }
                        } label: {
                            Text("저장")
                                .foregroundStyle(AppColors.successColor)
                        }
                    } else {
                        Button("달성") {
                            onToggle(achievedDate)
                            dismiss()
                        }
                        .foregroundStyle(AppColors.successColor)
                    }
                }
            }
            .onAppear {
                if let date = milestone.achievedDate {
                    achievedDate = date
                }
            }
        }
    }
}

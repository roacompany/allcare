import SwiftUI

// MARK: - PregnancyChecklistView
// 산전 체크리스트 화면.
// 번들 템플릿(source=bundle) + 사용자 추가(source=user) 혼합 표시.
// 카테고리별 섹션: trimester1/2/3/postpartum_prep/custom

struct PregnancyChecklistView: View {
    @Environment(PregnancyViewModel.self) private var pregnancyVM
    @Environment(AuthViewModel.self) private var authVM

    @State private var newItemTitle: String = ""
    @State private var isAddingItem = false

    // MARK: - Category Metadata

    private struct CategoryMeta {
        let id: String
        let title: String
        let icon: String
    }

    private let categories: [CategoryMeta] = [
        CategoryMeta(id: "trimester1", title: "1삼분기 (1~13주)", icon: "1.circle.fill"),
        CategoryMeta(id: "trimester2", title: "2삼분기 (14~27주)", icon: "2.circle.fill"),
        CategoryMeta(id: "trimester3", title: "3삼분기 (28~40주)", icon: "3.circle.fill"),
        CategoryMeta(id: "postpartum_prep", title: "출산 준비", icon: "bag.fill"),
        CategoryMeta(id: "custom", title: "나만의 목록", icon: "star.fill")
    ]

    // MARK: - Computed

    private var completedCount: Int {
        pregnancyVM.checklistItems.filter { $0.isCompleted }.count
    }

    private var totalCount: Int {
        pregnancyVM.checklistItems.count
    }

    private var completionRate: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }

    private func items(for categoryId: String) -> [PregnancyChecklistItem] {
        pregnancyVM.checklistItems
            .filter { $0.category == categoryId }
            .sorted { ($0.order ?? 0) < ($1.order ?? 0) }
    }

    // MARK: - Body

    var body: some View {
        List {
            // 면책 배너
            Section {
                ChecklistDisclaimerBanner(
                    text: "이 체크리스트는 일반적인 참고 자료입니다. 의학적 판단은 담당 의료진과 함께 하세요."
                )
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)

            // 완료율 카드
            if totalCount > 0 {
                Section {
                    completionHeader
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }

            // 카테고리별 섹션
            ForEach(categories, id: \.id) { meta in
                let sectionItems = items(for: meta.id)
                if !sectionItems.isEmpty || meta.id == "custom" {
                    Section {
                        if sectionItems.isEmpty {
                            Text("아직 추가된 항목이 없어요.")
                                .font(.subheadline)
                                .foregroundStyle(.tertiary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 8)
                        } else {
                            ForEach(sectionItems) { item in
                                PregnancyChecklistItemRow(item: item) {
                                    Task {
                                        guard let userId = authVM.currentUserId else { return }
                                        await pregnancyVM.toggleChecklistItem(item, userId: userId)
                                    }
                                }
                            }
                        }

                        if meta.id == "custom" {
                            addCustomItemRow
                        }
                    } header: {
                        Label(meta.title, systemImage: meta.icon)
                    }
                }
            }
        }
        .navigationTitle("산전 체크리스트")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard let userId = authVM.currentUserId else { return }
            await pregnancyVM.loadBundleChecklistIfNeeded(userId: userId)
        }
    }

    // MARK: - Completion Header

    private var completionHeader: some View {
        VStack(spacing: 10) {
            HStack {
                Text("완료")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(completedCount) / \(totalCount)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.primaryAccent)
            }
            ProgressView(value: completionRate)
                .tint(AppColors.primaryAccent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Add Custom Item Row

    private var addCustomItemRow: some View {
        HStack {
            if isAddingItem {
                TextField("새 항목 입력", text: $newItemTitle)
                    .onSubmit { saveNewItem() }
                Spacer()
                Button("추가") { saveNewItem() }
                    .foregroundStyle(AppColors.primaryAccent)
                    .disabled(newItemTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                Button("취소") {
                    newItemTitle = ""
                    isAddingItem = false
                }
                .foregroundStyle(.secondary)
            } else {
                Button {
                    isAddingItem = true
                } label: {
                    Label("항목 추가", systemImage: "plus.circle.fill")
                        .foregroundStyle(AppColors.primaryAccent)
                }
            }
        }
    }

    // MARK: - Helpers

    private func saveNewItem() {
        let title = newItemTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty, let userId = authVM.currentUserId else { return }
        Task {
            await pregnancyVM.addChecklistItem(title: title, category: "custom", userId: userId)
        }
        newItemTitle = ""
        isAddingItem = false
    }
}

// MARK: - PregnancyChecklistItemRow

private struct PregnancyChecklistItemRow: View {
    let item: PregnancyChecklistItem
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(item.isCompleted ? AppColors.primaryAccent : .secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.subheadline)
                        .strikethrough(item.isCompleted)
                        .foregroundStyle(item.isCompleted ? .secondary : .primary)

                    if let week = item.targetWeek {
                        Text("\(week)주 목표")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - ChecklistDisclaimerBanner

private struct ChecklistDisclaimerBanner: View {
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(.orange)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(.orange.opacity(0.4), lineWidth: 1)
        )
    }
}

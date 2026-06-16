import SwiftUI

// MARK: - 주차별 체크리스트 미니 (③검진 §섹션 5)

/// "이번 주 할 일" 요약 — 현재 삼분기 미완료 항목 top N(`PregnancyChecklistPlanner`) + 완료율 바 + 전체 push.
/// 자체 NavigationStack 금지(부모 검진 탭 스택 사용) — 중첩 크래시 회피 규칙.
struct WeeklyChecklistMiniCard: View {
    let highlights: [PregnancyChecklistItem]
    let completedCount: Int
    let totalCount: Int
    let completionRate: Double
    let onToggle: (PregnancyChecklistItem) -> Void

    var body: some View {
        DS2Card(tint: DS2.Color.pregnancy) {
            VStack(alignment: .leading, spacing: DS2.Spacing.md) {
                header
                if totalCount > 0 { progressBar }
                if highlights.isEmpty {
                    emptyOrDone
                } else {
                    VStack(spacing: DS2.Spacing.sm) {
                        ForEach(highlights) { item in
                            ChecklistMiniRow(item: item) { onToggle(item) }
                        }
                    }
                }
                NavigationLink {
                    PregnancyChecklistView()
                } label: {
                    HStack {
                        Text("전체 체크리스트")
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").font(.caption2)
                    }
                    .font(DS2.Font.subheadline)
                    .foregroundStyle(DS2.Color.pregnancy)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DS2.Spacing.xs) {
            Text("이번 주 할 일").font(DS2.Font.headline).foregroundStyle(DS2.Color.textPrimary)
            Text("내 주차에 맞춰 챙길 것을 모았어요")
                .font(DS2.Font.caption).foregroundStyle(DS2.Color.textSecondary)
        }
    }

    private var progressBar: some View {
        VStack(alignment: .leading, spacing: DS2.Spacing.xs) {
            HStack {
                Text("완료").font(DS2.Font.caption).foregroundStyle(DS2.Color.textSecondary)
                Spacer()
                Text("\(completedCount) / \(totalCount)")
                    .font(DS2.Font.caption).foregroundStyle(DS2.Color.pregnancy)
            }
            ProgressView(value: completionRate).tint(DS2.Color.pregnancy)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("체크리스트 완료 \(completedCount) / \(totalCount)")
    }

    @ViewBuilder private var emptyOrDone: some View {
        if totalCount == 0 {
            Text("전체 체크리스트에서 이번 주 할 일을 시작해보세요")
                .font(DS2.Font.caption).foregroundStyle(DS2.Color.textSecondary)
        } else {
            Label("이번 주 할 일을 다 마쳤어요", systemImage: "checkmark.seal")
                .font(DS2.Font.caption).foregroundStyle(DS2.Color.pregnancy)
        }
    }
}

private struct ChecklistMiniRow: View {
    let item: PregnancyChecklistItem
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: DS2.Spacing.sm) {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(item.isCompleted ? DS2.Color.pregnancy : DS2.Color.textSecondary)
                Text(item.title)
                    .font(DS2.Font.subheadline)
                    .strikethrough(item.isCompleted)
                    .foregroundStyle(item.isCompleted ? DS2.Color.textSecondary : DS2.Color.textPrimary)
                Spacer(minLength: 0)
                if let week = item.targetWeek {
                    Text("\(week)주").font(DS2.Font.caption2).foregroundStyle(DS2.Color.textSecondary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(item.title), \(item.isCompleted ? "완료" : "미완료")")
        .accessibilityHint("두 번 탭하면 완료를 바꿔요")
    }
}

// MARK: - 진료 준비 질문 메모 (③검진 §섹션 6)

/// 다음 검진에 임베딩되는 "물어볼 것" 메모. 체크(물어봤어요) 토글 + 인라인 추가. 검진 없으면 안내.
struct VisitQuestionMemoCard: View {
    let visit: PrenatalVisit?
    let onAdd: (String) -> Void
    let onToggle: (VisitPrepQuestion) -> Void
    let onDelete: (VisitPrepQuestion) -> Void

    @State private var draft = ""
    @FocusState private var inputFocused: Bool

    private var questions: [VisitPrepQuestion] { visit?.preparationQuestions ?? [] }

    var body: some View {
        DS2Card(tint: DS2.Color.pregnancy) {
            VStack(alignment: .leading, spacing: DS2.Spacing.md) {
                header
                if visit != nil {
                    if questions.isEmpty {
                        Text("아직 적어둔 질문이 없어요. 궁금한 걸 미리 적어두면 진료 때 잊지 않아요.")
                            .font(DS2.Font.caption).foregroundStyle(DS2.Color.textSecondary)
                    } else {
                        VStack(spacing: DS2.Spacing.sm) {
                            ForEach(questions) { q in
                                QuestionRow(question: q, onToggle: { onToggle(q) }, onDelete: { onDelete(q) })
                            }
                        }
                    }
                    addRow
                } else {
                    Text("다음 검진을 추가하면 물어볼 질문을 적어둘 수 있어요.")
                        .font(DS2.Font.caption).foregroundStyle(DS2.Color.textSecondary)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DS2.Spacing.xs) {
            Text("진료 때 물어볼 것").font(DS2.Font.headline).foregroundStyle(DS2.Color.textPrimary)
            Text("다음 검진에서 궁금한 걸 미리 적어두세요")
                .font(DS2.Font.caption).foregroundStyle(DS2.Color.textSecondary)
        }
    }

    private var addRow: some View {
        HStack(spacing: DS2.Spacing.sm) {
            TextField("질문 추가 (예: 철분제 계속 먹어도 되나요?)", text: $draft, axis: .vertical)
                .font(DS2.Font.subheadline)
                .focused($inputFocused)
                .submitLabel(.done)
                .onSubmit(add)
            Button(action: add) {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(draft.trimmingCharacters(in: .whitespaces).isEmpty
                                     ? DS2.Color.textSecondary : DS2.Color.pregnancy)
            }
            .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
            .accessibilityLabel("질문 추가")
        }
        .padding(.top, DS2.Spacing.xs)
    }

    private func add() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        onAdd(text)
        draft = ""
        inputFocused = false
    }
}

private struct QuestionRow: View {
    let question: VisitPrepQuestion
    let onToggle: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(alignment: .top, spacing: DS2.Spacing.sm) {
                Image(systemName: question.asked ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(question.asked ? DS2.Color.pregnancy : DS2.Color.textSecondary)
                Text(question.text)
                    .font(DS2.Font.subheadline)
                    .strikethrough(question.asked)
                    .foregroundStyle(question.asked ? DS2.Color.textSecondary : DS2.Color.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive, action: onDelete) { Label("삭제", systemImage: "trash") }
        }
        .accessibilityLabel("\(question.text), \(question.asked ? "물어봤어요" : "아직 안 물어봄")")
        .accessibilityHint("두 번 탭하면 물어봤어요로 바꿔요. 길게 누르면 삭제할 수 있어요")
    }
}

// MARK: - 음식·약물 안전 빠른 조회 (③검진 §섹션 7)

/// 컴팩트 진입 행 → FoodSafetySheet. 한국 임산부 맥락(회·커피·약). 도구함 자산.
struct FoodSafetyQuickRow: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            DS2Card(tint: DS2.Color.pregnancy) {
                HStack(spacing: DS2.Spacing.md) {
                    Image(systemName: "magnifyingglass")
                        .font(.title3).foregroundStyle(DS2.Color.pregnancy)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("임신 중 먹어도 될까?")
                            .font(DS2.Font.subheadline).foregroundStyle(DS2.Color.textPrimary)
                        Text("회·커피·약 등 빠른 조회")
                            .font(DS2.Font.caption2).foregroundStyle(DS2.Color.textSecondary)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(DS2.Color.textSecondary)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("음식·약물 안전 빠른 조회")
        .accessibilityHint("두 번 탭하면 검색 화면을 열어요")
    }
}

/// 음식·약물 안전 조회 시트 — `PregnancyFoodSafety`(의료감수 전 초안) 검색. 면책 동반·커머스 0.
struct FoodSafetySheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var results: [PregnancyFoodSafety.Item] { PregnancyFoodSafety.search(query) }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: DS2.Spacing.sm) {
                        Image(systemName: "info.circle.fill").foregroundStyle(DS2.Color.pregnancy)
                        Text(PregnancyFoodSafety.disclaimer)
                            .font(DS2.Font.caption).foregroundStyle(DS2.Color.textPrimary)
                    }
                    .accessibilityElement(children: .combine)
                }
                if results.isEmpty {
                    Section {
                        Text("‘\(query)’에 대한 안내를 찾지 못했어요. 담당 의료진과 상의하세요.")
                            .font(DS2.Font.caption).foregroundStyle(DS2.Color.textSecondary)
                    }
                } else {
                    Section {
                        ForEach(results) { FoodSafetyItemRow(item: $0) }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .searchable(text: $query, prompt: "음식·약 이름 검색 (예: 회, 커피, 약)")
            .navigationTitle("음식·약물 안전")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("닫기") { dismiss() } }
            }
        }
    }
}

private struct FoodSafetyItemRow: View {
    let item: PregnancyFoodSafety.Item

    private var levelColor: Color {
        switch item.level {
        case .generallyOk: return .green
        case .moderate: return .orange
        case .avoid: return .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS2.Spacing.xs) {
            HStack(spacing: DS2.Spacing.sm) {
                Text(item.name).font(DS2.Font.subheadline).foregroundStyle(DS2.Color.textPrimary)
                Spacer(minLength: 0)
                Label(item.level.label, systemImage: item.level.symbol)
                    .font(DS2.Font.caption2)
                    .padding(.horizontal, DS2.Spacing.sm).padding(.vertical, 2)
                    .background(levelColor.opacity(0.14), in: Capsule())
                    .foregroundStyle(levelColor)
            }
            Text(item.guidance).font(DS2.Font.caption).foregroundStyle(DS2.Color.textSecondary)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.name), \(item.level.label). \(item.guidance)")
    }
}

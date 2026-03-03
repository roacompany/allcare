import SwiftUI

// MARK: - RecordingView
// Main sheet presented when the user taps the "+" recording button.
// Shows category tabs (수유 / 수면 / 기저귀 / 건강) then sub-type options,
// then the relevant record form.

struct RecordingView: View {
    @Environment(ActivityViewModel.self) private var activityVM
    @Environment(BabyViewModel.self) private var babyVM
    @Environment(AuthViewModel.self) private var authVM
    @Environment(\.dismiss) private var dismiss

    // Selected tab
    @State private var selectedCategory: Activity.ActivityCategory = .feeding

    // Selected feeding sub-type (defaults to breast)
    @State private var selectedFeedingType: Activity.ActivityType = .feedingBreast

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // ── Category tab bar ───────────────────────────────────────
                CategoryTabBar(
                    selected: $selectedCategory,
                    onChange: { _ in
                        // Stop any running timer when switching top-level category
                        if activityVM.isTimerRunning { _ = activityVM.stopTimer() }
                        activityVM.resetForm()
                    }
                )
                .padding(.horizontal)
                .padding(.top, 8)

                // ── Sub-type picker (feeding only) ─────────────────────────
                if selectedCategory == .feeding {
                    FeedingSubPicker(selected: $selectedFeedingType)
                        .padding(.horizontal)
                        .padding(.top, 12)
                }

                Divider()
                    .padding(.top, 12)

                // ── Record form ────────────────────────────────────────────
                Group {
                    switch selectedCategory {
                    case .feeding:
                        FeedingRecordView(
                            type: selectedFeedingType,
                            onSaved: { dismiss() }
                        )
                    case .sleep:
                        SleepRecordView(onSaved: { dismiss() })
                    case .diaper:
                        DiaperRecordView(onSaved: { dismiss() })
                    case .health:
                        HealthRecordView(onSaved: { dismiss() })
                    }
                }
                .id(selectedCategory) // re-render on tab switch
            }
            .navigationTitle(babyVM.selectedBaby.map { "\($0.name) 기록" } ?? "기록")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") {
                        if activityVM.isTimerRunning { _ = activityVM.stopTimer() }
                        activityVM.resetForm()
                        dismiss()
                    }
                    .foregroundStyle(.secondary)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
        .alert("오류", isPresented: Binding(
            get: { activityVM.errorMessage != nil },
            set: { if !$0 { activityVM.errorMessage = nil } }
        )) {
            Button("확인", role: .cancel) { }
        } message: {
            Text(activityVM.errorMessage ?? "")
        }
    }
}

// MARK: - CategoryTabBar

private struct CategoryTabBar: View {
    @Binding var selected: Activity.ActivityCategory
    var onChange: ((Activity.ActivityCategory) -> Void)? = nil

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Activity.ActivityCategory.allCases, id: \.self) { category in
                Button {
                    guard selected != category else { return }
                    withAnimation(.spring(duration: 0.3)) {
                        selected = category
                    }
                    onChange?(category)
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: categoryIcon(category))
                            .font(.system(size: 20))
                        Text(category.displayName)
                            .font(.caption.bold())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        selected == category
                            ? categoryColor(category)
                            : categoryColor(category).opacity(0.08)
                    )
                    .foregroundStyle(selected == category ? .white : categoryColor(category))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func categoryIcon(_ cat: Activity.ActivityCategory) -> String {
        switch cat {
        case .feeding: "fork.knife"
        case .sleep:   "moon.zzz.fill"
        case .diaper:  "humidity.fill"
        case .health:  "heart.fill"
        }
    }

    private func categoryColor(_ cat: Activity.ActivityCategory) -> Color {
        switch cat {
        case .feeding: .pink
        case .sleep:   Color(hex: "7B9FE8")
        case .diaper:  Color(hex: "85C1A3")
        case .health:  Color(hex: "F4845F")
        }
    }
}

// MARK: - FeedingSubPicker

private struct FeedingSubPicker: View {
    @Environment(ActivityViewModel.self) private var activityVM
    @Binding var selected: Activity.ActivityType

    private let feedingTypes: [(Activity.ActivityType, String, String)] = [
        (.feedingBreast, "모유수유", "figure.and.child.holdinghands"),
        (.feedingBottle, "분유",    "cup.and.saucer.fill"),
        (.feedingSolid,  "이유식",  "fork.knife"),
        (.feedingSnack,  "간식",    "carrot.fill"),
    ]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(feedingTypes, id: \.0) { (type, label, icon) in
                Button {
                    guard selected != type else { return }
                    if activityVM.isTimerRunning { _ = activityVM.stopTimer() }
                    withAnimation(.spring(duration: 0.25)) { selected = type }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: icon)
                            .font(.body)
                        Text(label)
                            .font(.system(size: 11, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        selected == type
                            ? Color.pink
                            : Color.pink.opacity(0.08)
                    )
                    .foregroundStyle(selected == type ? .white : .pink)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Shared helper views used across all record forms

/// Multi-line note text editor with a consistent style.
struct NoteField: View {
    @Binding var note: String
    var accentColor: Color = .pink

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("메모 (선택)", systemImage: "note.text")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))

                if note.isEmpty {
                    Text("추가 내용을 입력하세요")
                        .font(.body)
                        .foregroundStyle(.tertiary)
                        .padding(12)
                }

                TextEditor(text: $note)
                    .font(.body)
                    .frame(minHeight: 72, maxHeight: 120)
                    .padding(8)
                    .scrollContentBackground(.hidden)
                    .background(.clear)
            }
            .frame(minHeight: 72)
        }
    }
}

/// Primary save button shared across all record forms.
struct SaveButton: View {
    let isSaving: Bool
    var color: Color = .pink
    let action: () -> Void

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            action()
        } label: {
            HStack(spacing: 10) {
                if isSaving {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                    Text("저장")
                        .font(.headline)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(color)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: color.opacity(0.35), radius: 8, y: 4)
        }
        .disabled(isSaving)
    }
}

// MARK: - ProductPickerSheet

/// 같은 카테고리에 용품이 2개 이상일 때 어떤 용품에서 차감할지 선택하는 시트
struct ProductPickerSheet: View {
    let products: [BabyProduct]
    let onSelect: (BabyProduct) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(products) { product in
                Button {
                    onSelect(product)
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: product.category.icon)
                            .font(.title3)
                            .foregroundStyle(Color(hex: "7B9FE8"))
                            .frame(width: 36)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(product.name)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                            if let brand = product.brand {
                                Text(brand)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        if let remaining = product.remainingQuantity {
                            Text("\(remaining)개 남음")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("사용할 용품 선택")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("건너뛰기") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    RecordingView()
        .environment(ActivityViewModel())
        .environment(BabyViewModel())
        .environment(AuthViewModel())
        .environment(ProductViewModel())
}

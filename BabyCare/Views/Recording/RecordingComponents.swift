import SwiftUI

// MARK: - CategoryTabBar

struct CategoryTabBar: View {
    @Binding var selected: Activity.ActivityCategory
    var onChange: ((Activity.ActivityCategory) -> Void)? = nil

    // 유축(.pumping)은 빠른기록 그리드 미니시트 전용 — 풀폼 탭바엔 미노출 (spec §3/§6).
    // allCases가 아닌 4-리터럴 상수라 신규 .pumping 카테고리가 탭으로 자동 노출되지 않음.
    private static let tabs: [Activity.ActivityCategory] = [.feeding, .sleep, .diaper, .health]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Self.tabs, id: \.self) { category in
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
                            .accessibilityHidden(true)
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
                .accessibilityLabel(category.displayName)
                .accessibilityAddTraits(selected == category ? [.isSelected] : [])
            }
        }
    }

    func categoryIcon(_ cat: Activity.ActivityCategory) -> String {
        switch cat {
        case .feeding: "fork.knife"
        case .sleep:   "moon.zzz.fill"
        case .diaper:  "humidity.fill"
        case .health:  "heart.fill"
        case .pumping: "drop.fill"
        }
    }

    func categoryColor(_ cat: Activity.ActivityCategory) -> Color {
        switch cat {
        case .feeding: .pink
        case .sleep:   AppColors.indigoColor
        case .diaper:  AppColors.sageColor
        case .health:  AppColors.coralColor
        case .pumping: AppColors.pumpingColor
        }
    }
}

// MARK: - FeedingSubPicker

struct FeedingSubPicker: View {
    @Environment(ActivityViewModel.self) var activityVM
    @Binding var selected: Activity.ActivityType

    let feedingTypes: [(Activity.ActivityType, String, String)] = [
        (.feedingBreast, "모유수유", "figure.and.child.holdinghands"),
        (.feedingBottle, "분유",    "cup.and.saucer.fill"),
        (.feedingSolid,  "이유식",  "fork.knife"),
        (.feedingSnack,  "간식",    "carrot.fill"),
        (.feedingPumping, "유축",     "drop.fill"),
    ]

    private func chipColor(_ type: Activity.ActivityType) -> Color {
        type == .feedingPumping ? AppColors.pumpingColor : .pink   // 유축=보라(생산 구분), 그 외 수유=핑크
    }

    var body: some View {
        // 평소엔 한 줄 5칸, 큰 Dynamic Type에서 잘리면 3+2 두 줄로 reflow (a11y)
        ViewThatFits(in: .horizontal) {
            chipRow(feedingTypes)
            VStack(spacing: 8) {
                chipRow(Array(feedingTypes.prefix(3)))
                chipRow(Array(feedingTypes.suffix(from: 3)))
            }
        }
    }

    @ViewBuilder
    private func chipRow(_ types: [(Activity.ActivityType, String, String)]) -> some View {
        HStack(spacing: 8) {
            ForEach(types, id: \.0) { (type, label, icon) in
                chip(type: type, label: label, icon: icon)
            }
        }
    }

    @ViewBuilder
    private func chip(type: Activity.ActivityType, label: String, icon: String) -> some View {
        let color = chipColor(type)
        Button {
            guard selected != type else { return }
            if activityVM.isTimerRunning { _ = activityVM.stopTimer() }
            withAnimation(.spring(duration: 0.25)) { selected = type }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.body)
                    .accessibilityHidden(true)
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(selected == type ? color : color.opacity(0.08))
            .foregroundStyle(selected == type ? .white : color)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(selected == type ? [.isSelected] : [])
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
    var isEnabled: Bool = true
    var color: Color = .pink
    let action: () -> Void

    private var effectiveColor: Color {
        isEnabled ? color : Color(.systemGray3)
    }

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
            .background(effectiveColor)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: effectiveColor.opacity(0.35), radius: 8, y: 4)
        }
        .disabled(isSaving || !isEnabled)
    }
}

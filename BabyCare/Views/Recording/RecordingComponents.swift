import SwiftUI

// MARK: - CategoryTabBar (라이브 v2.8.6 폼 복원)

struct CategoryTabBar: View {
    @Binding var selected: Activity.ActivityCategory
    var onChange: ((Activity.ActivityCategory) -> Void)? = nil

    // 유축(.pumping)은 빠른기록 그리드 미니시트 전용 — 풀폼 탭바엔 미노출.
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
                    // 색은 '선택된 것'만 낸다 — 미선택은 중립 + 카테고리색 아이콘 (기록 UX 재작업 2026-08-20).
                    // 선택 색은 Activity 단일 소스(emphasisColor) — 폼별 색 하드코딩 금지.
                    let isSelected = selected == category
                    let emphasis = Color(category.emphasisColor)
                    VStack(spacing: 5) {
                        Image(systemName: categoryIcon(category))
                            .font(.system(size: 20))
                            .foregroundStyle(isSelected ? Color.white : emphasis)
                            .accessibilityHidden(true)
                        Text(category.displayName)
                            .font(.caption.bold())
                            .foregroundStyle(isSelected ? Color.white : Color.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(isSelected ? emphasis : Color(.systemGray6))
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
        case .unknown: "questionmark.circle"
        }
    }
}

// MARK: - FeedingSubPicker (라이브 v2.8.6 폼 복원 · feedingPumping="유축" 유지)

struct FeedingSubPicker: View {
    @Environment(ActivityViewModel.self) var activityVM
    @Binding var selected: Activity.ActivityType

    let feedingTypes: [(Activity.ActivityType, String, String)] = [
        (.feedingBreast, "모유",    "figure.and.child.holdinghands"),
        (.feedingBottle, "분유",    "waterbottle.fill"),
        (.feedingSolid,  "이유식",  "fork.knife"),
        (.feedingSnack,  "간식",    "carrot.fill"),
        (.feedingPumping, "유축",    "drop.fill"),
    ]

    // 칩 색 = Activity 단일 소스(emphasisColor) — 모유/분유=수유 계열, 이유식/간식=민트 계열, 유축=보라(생산).

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
        let isSelected = selected == type
        let emphasis = Color(type.emphasisColor)
        Button {
            guard selected != type else { return }
            if activityVM.isTimerRunning { _ = activityVM.stopTimer() }
            withAnimation(.spring(duration: 0.25)) { selected = type }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundStyle(isSelected ? Color.white : emphasis)
                    .accessibilityHidden(true)
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.white : Color.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(isSelected ? emphasis : Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(selected == type ? [.isSelected] : [])
    }
}

// MARK: - Shared helper views used across record forms

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

/// Primary save button shared across record forms.
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

/// 폼 하단 고정 저장 바 — 저장 버튼이 스크롤 맨 아래에 묻히지 않게 `safeAreaInset(edge: .bottom)`으로 상주.
/// (기록 UX 재작업 2026-08-20 — 모든 기록 폼 공용)
struct SaveBar: View {
    let isSaving: Bool
    var isEnabled: Bool = true
    var color: Color = .pink
    let action: () -> Void

    var body: some View {
        SaveButton(isSaving: isSaving, isEnabled: isEnabled, color: color, action: action)
            .padding(.horizontal)
            .padding(.top, 10)
            .padding(.bottom, 6)
            .frame(maxWidth: .infinity)
            .background(.thinMaterial)
            .overlay(alignment: .top) { Divider() }
    }
}

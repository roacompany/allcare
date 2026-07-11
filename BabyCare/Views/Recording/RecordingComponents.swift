import SwiftUI

// MARK: - Shared helper views used across record forms
// (CategoryTabBar / FeedingSubPicker 는 P4에서 제거 — 타입-우선 그리드/런처로 대체)

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

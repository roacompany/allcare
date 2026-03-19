import SwiftUI
import UIKit

// MARK: - Checklist Item Row

struct ChecklistItemRow: View {
    let item: AIReport.ChecklistItem
    let isChecked: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.body)
                    .foregroundStyle(isChecked ? .green : .secondary)
                    .animation(.spring(duration: 0.2), value: isChecked)
                Text(item.question)
                    .font(.subheadline)
                    .foregroundStyle(isChecked ? .secondary : .primary)
                    .strikethrough(isChecked, color: .secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .animation(.easeInOut(duration: 0.2), value: isChecked)
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let text: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [text], applicationActivities: nil)
    }

    func updateUIViewController(_ uvc: UIActivityViewController, context: Context) {}
}

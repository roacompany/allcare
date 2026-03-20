import SwiftUI

// MARK: - DiaperTypeCard

struct DiaperTypeCard: View {
    let label: String
    let icon: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(isSelected ? color : color.opacity(0.12))
                        .frame(width: 48, height: 48)
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(isSelected ? .white : color)
                        .accessibilityHidden(true)
                }

                Text(label)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(isSelected ? color : .primary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(color)
                        .transition(.scale.combined(with: .opacity))
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? color.opacity(0.1) : Color(.systemBackground))
                    .shadow(
                        color: isSelected ? color.opacity(0.2) : .black.opacity(0.05),
                        radius: isSelected ? 8 : 4,
                        y: 2
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? color.opacity(0.4) : Color(.systemGray5), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isSelected ? "\(label), 선택됨" : label)
    }
}

#Preview {
    DiaperRecordView()
        .environment(ActivityViewModel())
        .environment(BabyViewModel())
        .environment(AuthViewModel())
}

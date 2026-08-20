import SwiftUI

// MARK: - DiaperTypeCard

struct DiaperTypeCard: View {
    let label: String
    let icon: String
    let isSelected: Bool
    let color: Color
    /// 소변+대변 전용 앰버 물방울 배지 — 대변과 아이콘이 같아(SF 한계) 라벨 외 변별자 추가 (2026-08-20 재작업).
    var showsBothBadge: Bool = false
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
                .overlay(alignment: .bottomTrailing) {
                    if showsBothBadge {
                        ZStack {
                            Circle()
                                .fill(Color(.systemBackground))
                                .frame(width: 20, height: 20)
                                .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                            Image(systemName: "drop.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(AppColors.diaperEmphasis)
                        }
                        .offset(x: 3, y: 3)
                        .accessibilityHidden(true)
                    }
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

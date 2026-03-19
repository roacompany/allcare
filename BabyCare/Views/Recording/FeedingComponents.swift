import SwiftUI

// MARK: - FlowLayout (칩 정렬용)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
        }

        return (CGSize(width: maxWidth, height: currentY + lineHeight), positions)
    }
}

// MARK: - SideButton

struct SideButton: View {
    let side: Activity.BreastSide
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: sideIcon)
                    .font(.title3)
                Text(side.displayName)
                    .font(.caption.bold())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? color : color.opacity(0.08))
            .foregroundStyle(isSelected ? .white : color)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? color : .clear, lineWidth: 2)
            )
        }
        .animation(.spring(duration: 0.25), value: isSelected)
    }

    var sideIcon: String {
        switch side {
        case .left:  "arrow.left"
        case .right: "arrow.right"
        case .both:  "arrow.left.arrow.right"
        }
    }
}

#Preview {
    FeedingRecordView(type: .feedingBreast)
        .environment(ActivityViewModel())
        .environment(BabyViewModel())
        .environment(AuthViewModel())
        .environment(ProductViewModel())
}

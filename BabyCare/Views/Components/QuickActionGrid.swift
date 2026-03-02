import SwiftUI

struct QuickActionGrid: View {
    let onSelect: (Activity.ActivityType) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)
    private let actions: [(Activity.ActivityType, Color)] = [
        (.feedingBreast, Color(hex: "FF9FB5")),
        (.feedingBottle, Color(hex: "FF9FB5")),
        (.feedingSolid, Color(hex: "9FDFBF")),
        (.sleep, Color(hex: "9FB5FF")),
        (.diaperWet, Color(hex: "FFD59F")),
        (.diaperDirty, Color(hex: "FFD59F")),
        (.bath, Color(hex: "9FD5FF")),
        (.temperature, Color(hex: "FF9F9F")),
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(actions, id: \.0) { type, color in
                Button {
                    onSelect(type)
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: type.icon)
                            .font(.title3)
                            .frame(width: 44, height: 44)
                            .background(color.opacity(0.15))
                            .foregroundStyle(color)
                            .clipShape(Circle())

                        Text(type.displayName)
                            .font(.caption2)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

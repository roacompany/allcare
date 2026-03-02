import SwiftUI

struct BabySelectorView: View {
    let babies: [Baby]
    let selectedBaby: Baby?
    let onSelect: (Baby) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(babies) { baby in
                    Button {
                        onSelect(baby)
                    } label: {
                        HStack(spacing: 8) {
                            Text(baby.gender.emoji)
                                .font(.title3)

                            VStack(alignment: .leading, spacing: 1) {
                                Text(baby.name)
                                    .font(.subheadline.weight(.semibold))
                                Text(baby.ageText)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            selectedBaby?.id == baby.id
                                ? Color.accentColor.opacity(0.12)
                                : Color(.systemGray6)
                        )
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(
                                    selectedBaby?.id == baby.id
                                        ? Color.accentColor
                                        : Color.clear,
                                    lineWidth: 1.5
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
    }
}

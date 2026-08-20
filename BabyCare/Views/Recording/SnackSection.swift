import SwiftUI

// MARK: - SnackSection (간식)

struct SnackSection: View {
    @Environment(ActivityViewModel.self) var activityVM
    let accentColor: Color

    let snackChips = ["과일", "떡뻥", "퓨레", "요거트", "치즈", "빵"]
    let amountChips = ["조금", "반개", "1개", "한줌"]

    var body: some View {
        @Bindable var vm = activityVM

        VStack(alignment: .leading, spacing: 16) {
            // 음식명
            VStack(alignment: .leading, spacing: 8) {
                Label("간식 이름", systemImage: "carrot.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)

                TextField("간식 이름 입력", text: $vm.foodName)
                    .padding(14)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                Text("자주 쓰는 간식")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                FlowLayout(spacing: 8) {
                    ForEach(snackChips, id: \.self) { chip in
                        Button(chip) {
                            activityVM.foodName = activityVM.foodName == chip ? "" : chip
                        }
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            activityVM.foodName == chip
                                ? accentColor : accentColor.opacity(0.1)
                        )
                        .foregroundStyle(
                            activityVM.foodName == chip ? .white : accentColor
                        )
                        .clipShape(Capsule())
                    }
                }
            }

            Divider()

            // 섭취량
            VStack(alignment: .leading, spacing: 8) {
                Label("섭취량", systemImage: "chart.bar.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    ForEach(amountChips, id: \.self) { chip in
                        Button(chip) {
                            activityVM.foodAmount = activityVM.foodAmount == chip ? "" : chip
                        }
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            activityVM.foodAmount == chip
                                ? accentColor : accentColor.opacity(0.1)
                        )
                        .foregroundStyle(
                            activityVM.foodAmount == chip ? .white : accentColor
                        )
                        .clipShape(Capsule())
                    }
                }
            }
        }
        .padding()
        .background(accentColor.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

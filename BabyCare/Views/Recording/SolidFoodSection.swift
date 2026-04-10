import SwiftUI

import SwiftUI

// MARK: - SolidFoodSection (이유식)

struct SolidFoodSection: View {
    @Environment(ActivityViewModel.self) var activityVM
    let accentColor: Color

    let ingredientChips = ["쌀미음", "감자", "고구마", "당근", "브로콜리", "소고기", "닭고기", "바나나", "사과", "두부"]
    let amountChips = ["1숟가락", "3숟가락", "5숟가락", "30g", "50g", "80g", "100g"]

    var body: some View {
        @Bindable var vm = activityVM

        VStack(alignment: .leading, spacing: 16) {
            // 음식명
            VStack(alignment: .leading, spacing: 8) {
                Label("음식 이름", systemImage: "fork.knife")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)

                TextField("음식 이름 입력", text: $vm.foodName)
                    .padding(14)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                Text("자주 쓰는 재료")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                FlowLayout(spacing: 8) {
                    ForEach(ingredientChips, id: \.self) { chip in
                        Button(chip) {
                            let items = activityVM.foodName.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                            if items.contains(chip) {
                                activityVM.foodName = items.filter { $0 != chip }.joined(separator: ", ")
                            } else {
                                activityVM.foodName = activityVM.foodName.isEmpty ? chip : activityVM.foodName + ", " + chip
                            }
                        }
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            activityVM.foodName.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.contains(chip)
                                ? accentColor : accentColor.opacity(0.1)
                        )
                        .foregroundStyle(
                            activityVM.foodName.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.contains(chip) ? .white : accentColor
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

                FlowLayout(spacing: 8) {
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

            Divider()

            // 반응
            VStack(alignment: .leading, spacing: 8) {
                Label("아기 반응", systemImage: "face.smiling.inverse")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    ForEach(Activity.FoodReaction.allCases, id: \.self) { reaction in
                        Button {
                            activityVM.foodReaction = activityVM.foodReaction == reaction ? nil : reaction
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: reaction.icon)
                                    .font(.body)
                                Text(reaction.displayName)
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                activityVM.foodReaction == reaction
                                    ? (reaction == .allergy ? Color.red : accentColor)
                                    : (reaction == .allergy ? Color.red.opacity(0.08) : accentColor.opacity(0.08))
                            )
                            .foregroundStyle(
                                activityVM.foodReaction == reaction
                                    ? .white
                                    : (reaction == .allergy ? .red : accentColor)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }

                // 알레르기 경고 배너
                if activityVM.foodReaction == .allergy {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.white)
                        Text("알레르기 반응이 의심됩니다. 소아과 상담을 권장합니다.")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .padding()
        .background(accentColor.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .animation(.spring(duration: 0.3), value: activityVM.foodReaction)
    }
}

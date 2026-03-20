import SwiftUI

struct BabyFoodRecipeDetailView: View {
    let recipe: BabyFoodRecipe

    private var stageColor: Color {
        Color(hex: recipe.stage.colorHex)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 헤더
                RecipeHeaderView(recipe: recipe, stageColor: stageColor)
                    .padding(.horizontal)

                // 알레르기 경고
                if !recipe.allergyWarnings.isEmpty {
                    AllergyWarningSection(warnings: recipe.allergyWarnings)
                        .padding(.horizontal)
                }

                // 재료
                RecipeSectionCard(
                    title: "재료",
                    icon: "cart.fill",
                    iconColor: stageColor
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(recipe.ingredients.enumerated()), id: \.offset) { _, ingredient in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(stageColor)
                                    .frame(width: 6, height: 6)
                                Text(ingredient)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                }
                .padding(.horizontal)

                // 만드는 법
                RecipeSectionCard(
                    title: "만드는 법",
                    icon: "list.number",
                    iconColor: stageColor
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, step in
                            HStack(alignment: .top, spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(stageColor)
                                        .frame(width: 24, height: 24)
                                    Text("\(index + 1)")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.white)
                                }
                                Text(step)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
                .padding(.horizontal)

                Spacer(minLength: 24)
            }
            .padding(.top, 12)
        }
        .navigationTitle(recipe.title)
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - RecipeHeaderView

private struct RecipeHeaderView: View {
    let recipe: BabyFoodRecipe
    let stageColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(recipe.stage.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(stageColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(stageColor.opacity(0.15))
                    .clipShape(Capsule())

                Text(recipe.stage.monthRangeText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(Capsule())
            }

            Text(recipe.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(stageColor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - AllergyWarningSection

private struct AllergyWarningSection: View {
    let warnings: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.subheadline)
                Text("알레르기 주의 식재료")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.red)
            }
            HStack(spacing: 6) {
                ForEach(warnings, id: \.self) { warning in
                    AllergyBadge(text: warning)
                }
            }
            Text("처음 먹일 때는 소량부터 시작하고 4~5일 후 반응을 확인하세요.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(Color.red.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.red.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - RecipeSectionCard

private struct RecipeSectionCard<Content: View>: View {
    let title: String
    let icon: String
    let iconColor: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(iconColor)
                    .font(.subheadline)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

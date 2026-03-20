import SwiftUI

struct BabyFoodStageView: View {
    let stage: BabyFoodStage

    private var stageColor: Color {
        Color(hex: stage.colorHex)
    }

    private var recipes: [BabyFoodRecipe] {
        BabyFoodGuideData.recipes(for: stage)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 단계 헤더
                StageHeaderBanner(stage: stage)
                    .padding(.horizontal)

                // 레시피 목록
                VStack(spacing: 12) {
                    ForEach(recipes) { recipe in
                        NavigationLink {
                            BabyFoodRecipeDetailView(recipe: recipe)
                        } label: {
                            RecipeRowCard(recipe: recipe, stageColor: stageColor)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
            .padding(.top, 8)
        }
        .navigationTitle(stage.title)
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - StageHeaderBanner

private struct StageHeaderBanner: View {
    let stage: BabyFoodStage

    private var stageColor: Color {
        Color(hex: stage.colorHex)
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(stageColor.opacity(0.2))
                    .frame(width: 56, height: 56)
                Image(systemName: stage.icon)
                    .font(.title2)
                    .foregroundStyle(stageColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(stage.monthRangeText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(stage.subtitle)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text("\(BabyFoodGuideData.recipes(for: stage).count)가지 레시피 수록")
                    .font(.caption)
                    .foregroundStyle(stageColor)
            }
            Spacer()
        }
        .padding(16)
        .background(stageColor.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - RecipeRowCard

private struct RecipeRowCard: View {
    let recipe: BabyFoodRecipe
    let stageColor: Color

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(stageColor.opacity(0.15))
                    .frame(width: 46, height: 46)
                Image(systemName: "fork.knife")
                    .font(.body)
                    .foregroundStyle(stageColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(recipe.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(recipe.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                if !recipe.allergyWarnings.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(recipe.allergyWarnings, id: \.self) { warning in
                            AllergyBadge(text: warning)
                        }
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - AllergyBadge

struct AllergyBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Color.red.opacity(0.85))
            .clipShape(Capsule())
    }
}

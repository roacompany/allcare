import SwiftUI

struct BabyFoodGuideView: View {
    @Environment(BabyViewModel.self) private var babyVM

    private var currentAgeMonths: Int {
        guard let baby = babyVM.selectedBaby else { return 0 }
        return Calendar.current.dateComponents([.month], from: baby.birthDate, to: Date()).month ?? 0
    }

    private var currentStage: BabyFoodStage? {
        BabyFoodStage.allCases.first { $0.contains(ageInMonths: currentAgeMonths) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 현재 월령 헤더
                if let baby = babyVM.selectedBaby {
                    CurrentStageHeaderView(
                        babyName: baby.name,
                        ageMonths: currentAgeMonths,
                        currentStage: currentStage
                    )
                    .padding(.horizontal)
                }

                // 단계 목록
                VStack(spacing: 12) {
                    ForEach(BabyFoodStage.allCases) { stage in
                        NavigationLink {
                            BabyFoodStageView(stage: stage)
                        } label: {
                            BabyFoodStageCard(
                                stage: stage,
                                isCurrent: stage == currentStage
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)

                // 주의사항 안내
                AllergyNoticeView()
                    .padding(.horizontal)
                    .padding(.bottom, 16)
            }
            .padding(.top, 8)
        }
        .navigationTitle("이유식 가이드")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - CurrentStageHeaderView

private struct CurrentStageHeaderView: View {
    let babyName: String
    let ageMonths: Int
    let currentStage: BabyFoodStage?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(babyName) · \(ageMonths)개월")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if let stage = currentStage {
                        Text("지금은 \(stage.title) 단계예요")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.primary)
                    } else if ageMonths < 4 {
                        Text("아직 이유식 시작 전이에요")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.primary)
                    } else {
                        Text("이유식 졸업을 축하해요!")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.primary)
                    }
                }
                Spacer()
                Image(systemName: currentStage?.icon ?? "fork.knife")
                    .font(.title)
                    .foregroundStyle(Color(hex: currentStage?.colorHex ?? "85C1A3"))
            }

            if let stage = currentStage {
                Text(stage.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(hex: stage.colorHex).opacity(0.15))
                    .clipShape(Capsule())
            }
        }
        .padding(16)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - BabyFoodStageCard

private struct BabyFoodStageCard: View {
    let stage: BabyFoodStage
    let isCurrent: Bool

    private var stageColor: Color {
        Color(hex: stage.colorHex)
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(stageColor.opacity(0.2))
                    .frame(width: 50, height: 50)
                Image(systemName: stage.icon)
                    .font(.title2)
                    .foregroundStyle(stageColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(stage.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    if isCurrent {
                        Text("지금 단계")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(stageColor)
                            .clipShape(Capsule())
                    }
                }
                Text(stage.monthRangeText + " · " + stage.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("\(BabyFoodGuideData.recipes(for: stage).count)가지 레시피")
                    .font(.caption)
                    .foregroundStyle(stageColor)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .background(isCurrent ? stageColor.opacity(0.08) : Color(.systemBackground).opacity(0.0))
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(isCurrent ? stageColor.opacity(0.4) : .clear, lineWidth: 1.5)
        )
    }
}

// MARK: - AllergyNoticeView

private struct AllergyNoticeView: View {
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.subheadline)
            VStack(alignment: .leading, spacing: 4) {
                Text("알레르기 주의")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.orange)
                Text("새로운 식재료는 하나씩 4~5일 간격으로 도입하세요. 발진, 두드러기, 구토 등의 증상이 나타나면 즉시 중단하고 소아과에 방문하세요.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

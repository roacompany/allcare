import SwiftUI

struct DevelopmentCardView: View {
    let card: DevelopmentCard
    let babyAgeMonths: Int

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    headerSection

                    Divider()

                    // Body text
                    Text(card.body)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .lineSpacing(6)
                        .padding(.horizontal)

                    // Month range badge
                    monthRangeBadge
                        .padding(.horizontal)

                    Spacer(minLength: 40)
                }
                .padding(.top, 20)
            }
            .navigationTitle("콘텐츠 상세")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text(card.emoji)
                    .font(.system(size: 40))

                VStack(alignment: .leading, spacing: 4) {
                    categoryBadge
                    if card.isRecommended(for: babyAgeMonths) {
                        recommendedBadge
                    }
                }
            }
            .padding(.horizontal)

            Text(card.title)
                .font(.title2.weight(.bold))
                .foregroundStyle(.primary)
                .padding(.horizontal)
        }
    }

    // MARK: - Badges

    private var categoryBadge: some View {
        HStack(spacing: 4) {
            Text(card.category.emoji)
                .font(.caption)
            Text(card.category.rawValue)
                .font(.caption.weight(.semibold))
                .foregroundStyle(card.category.color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(card.category.color.opacity(0.15))
        .clipShape(Capsule())
    }

    private var recommendedBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill")
                .font(.caption2)
            Text("현재 월령 추천")
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(AppColors.warmOrangeColor)
        .clipShape(Capsule())
    }

    private var monthRangeBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "calendar")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("적용 월령: 생후 \(card.monthRange.lowerBound)~\(card.monthRange.upperBound)개월")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

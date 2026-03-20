import SwiftUI

struct DevelopmentContentView: View {
    @Environment(BabyViewModel.self) private var babyVM

    @State private var selectedCategory: DevelopmentCategory? = nil
    @State private var showRecommendedOnly = false
    @State private var selectedCard: DevelopmentCard? = nil

    private var babyAgeMonths: Int {
        guard let baby = babyVM.selectedBaby else { return 0 }
        let months = Calendar.current.dateComponents([.month], from: baby.birthDate, to: Date()).month ?? 0
        return max(0, months)
    }

    private var filteredCards: [DevelopmentCard] {
        var cards = DevelopmentCard.all

        if let category = selectedCategory {
            cards = cards.filter { $0.category == category }
        }

        if showRecommendedOnly {
            cards = cards.filter { $0.isRecommended(for: babyAgeMonths) }
        }

        return cards
    }

    private var recommendedCount: Int {
        DevelopmentCard.recommended(for: babyAgeMonths).count
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // 월령 배너
                if let baby = babyVM.selectedBaby {
                    ageBanner(baby: baby)
                }

                // 카테고리 필터
                categoryFilter
                    .padding(.vertical, 12)

                // 추천 필터 토글
                if recommendedCount > 0 {
                    recommendedToggle
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                }

                // 카드 목록
                if filteredCards.isEmpty {
                    emptyState
                } else {
                    cardList
                }
            }
        }
        .navigationTitle("발달 콘텐츠")
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $selectedCard) { card in
            DevelopmentCardView(card: card, babyAgeMonths: babyAgeMonths)
        }
    }

    // MARK: - Age Banner

    private func ageBanner(baby: Baby) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(baby.name) · 생후 \(babyAgeMonths)개월")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text("현재 월령 맞춤 콘텐츠 \(recommendedCount)개")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("📚")
                .font(.system(size: 36))
        }
        .padding(16)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    // MARK: - Category Filter

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // 전체 버튼
                CategoryChip(
                    label: "전체",
                    emoji: "📋",
                    color: .secondary,
                    isSelected: selectedCategory == nil
                ) {
                    selectedCategory = nil
                }

                ForEach(DevelopmentCategory.allCases) { category in
                    CategoryChip(
                        label: category.rawValue,
                        emoji: category.emoji,
                        color: category.color,
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = selectedCategory == category ? nil : category
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Recommended Toggle

    private var recommendedToggle: some View {
        Button {
            showRecommendedOnly.toggle()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: showRecommendedOnly ? "star.fill" : "star")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.warmOrangeColor)
                Text("현재 월령 추천만 보기")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(recommendedCount)개")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(AppColors.warmOrangeColor)
                    .clipShape(Capsule())
            }
            .padding(12)
            .background(
                showRecommendedOnly
                    ? AppColors.warmOrangeColor.opacity(0.12)
                    : Color.secondary.opacity(0.08)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        showRecommendedOnly ? AppColors.warmOrangeColor.opacity(0.4) : Color.clear,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Card List

    private var cardList: some View {
        LazyVStack(spacing: 12) {
            // 추천 카드 섹션 (필터 off 상태에서 상단 노출)
            if !showRecommendedOnly {
                let recommended = filteredCards.filter { $0.isRecommended(for: babyAgeMonths) }
                if !recommended.isEmpty {
                    sectionHeader(title: "현재 월령 추천", count: recommended.count, icon: "star.fill", color: AppColors.warmOrangeColor)

                    ForEach(recommended) { card in
                        DevelopmentCardRow(card: card, babyAgeMonths: babyAgeMonths, isRecommended: true)
                            .onTapGesture { selectedCard = card }
                    }

                    let others = filteredCards.filter { !$0.isRecommended(for: babyAgeMonths) }
                    if !others.isEmpty {
                        sectionHeader(title: "다른 콘텐츠", count: others.count, icon: "doc.text", color: .secondary)
                        ForEach(others) { card in
                            DevelopmentCardRow(card: card, babyAgeMonths: babyAgeMonths, isRecommended: false)
                                .onTapGesture { selectedCard = card }
                        }
                    }
                } else {
                    ForEach(filteredCards) { card in
                        DevelopmentCardRow(card: card, babyAgeMonths: babyAgeMonths, isRecommended: false)
                            .onTapGesture { selectedCard = card }
                    }
                }
            } else {
                ForEach(filteredCards) { card in
                    DevelopmentCardRow(card: card, babyAgeMonths: babyAgeMonths, isRecommended: true)
                        .onTapGesture { selectedCard = card }
                }
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 20)
    }

    private func sectionHeader(title: String, count: Int, icon: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("\(count)")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(color)
                .clipShape(Capsule())
            Spacer()
        }
        .padding(.top, 8)
        .padding(.bottom, 2)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Text("📭")
                .font(.system(size: 48))
            Text("해당하는 콘텐츠가 없어요")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("필터를 변경해 보세요")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

// MARK: - Category Chip

private struct CategoryChip: View {
    let label: String
    let emoji: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(emoji)
                    .font(.caption)
                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isSelected ? .white : color)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(isSelected ? color : color.opacity(0.12))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.18), value: isSelected)
    }
}

// MARK: - Development Card Row

private struct DevelopmentCardRow: View {
    let card: DevelopmentCard
    let babyAgeMonths: Int
    let isRecommended: Bool

    private let bodyPreviewLength = 80

    private var bodyPreview: String {
        let trimmed = card.body.prefix(bodyPreviewLength)
        return card.body.count > bodyPreviewLength ? "\(trimmed)..." : String(trimmed)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top: emoji + title + badges
            HStack(alignment: .top, spacing: 12) {
                Text(card.emoji)
                    .font(.system(size: 32))
                    .frame(width: 44, height: 44)
                    .background(card.category.color.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text(card.category.emoji + " " + card.category.rawValue)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(card.category.color)

                        if isRecommended {
                            Text("추천")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(AppColors.warmOrangeColor)
                                .clipShape(Capsule())
                        }
                    }

                    Text(card.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(14)

            // Divider + preview
            Divider()
                .padding(.horizontal, 14)

            Text(bodyPreview)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .padding(14)

            // Month range
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Text("생후 \(card.monthRange.lowerBound)~\(card.monthRange.upperBound)개월")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 12)
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    isRecommended ? AppColors.warmOrangeColor.opacity(0.35) : Color.clear,
                    lineWidth: 1.5
                )
        )
    }
}

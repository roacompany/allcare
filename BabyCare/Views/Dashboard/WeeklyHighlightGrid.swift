import SwiftUI
import Charts

// MARK: - WeeklyHighlightGrid

/// 주간 하이라이트 4-카드 그리드 (Feeding / Sleep / Diaper / Health).
/// - 각 카드: 아이콘 + 카테고리명 + WoW % 배지 (↑/↓) + 4주 Sparkline (h:40)
/// - 빈 sparkline: placeholder rect (회색)
/// - pregnancyOnly 시 hidden → parent에서 gating
/// - InsightService는 parent에서 [Double] 주입. 직접 참조 금지.
struct WeeklyHighlightGrid: View, Equatable {

    // MARK: - Equatable

    nonisolated static func == (lhs: WeeklyHighlightGrid, rhs: WeeklyHighlightGrid) -> Bool {
        lhs.cards == rhs.cards
    }

    // MARK: - Model

    struct CardData: Equatable {
        let category: InsightCategory
        let metricKey: String
        /// 최근 4주 sparkline 값 (parent에서 InsightService.sparklineData(for:) 호출 후 주입).
        let sparkline: [Double]
        /// 전주 대비 변화율 (양수=증가, 음수=감소).
        let changePercent: Double
    }

    // MARK: - Inputs

    /// 4 카드 고정 (Feeding / Sleep / Diaper / Health 순서).
    /// parent에서 sparkline [Double] 주입. InsightService 직접 호출 금지.
    let cards: [CardData]

    // MARK: - Body

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(Array(cards.enumerated()), id: \.offset) { index, card in
                HighlightCard(card: card)
                    .accessibilityIdentifier("highlightCard_\(index)")
                    .onTapGesture {
                        AnalyticsService.shared.trackEvent(
                            AnalyticsEvents.highlightCardTapped,
                            parameters: [
                                AnalyticsParams.category: card.category.rawValue
                            ]
                        )
                    }
            }
        }
    }
}

// MARK: - WeeklyHighlightGridContainer

/// `.equatable()` modifier 적용을 위한 컨테이너.
/// LazyVGrid 재렌더 최적화 — 동일 cards일 때 diff skip.
struct WeeklyHighlightGridContainer: View {

    let cards: [WeeklyHighlightGrid.CardData]

    var body: some View {
        WeeklyHighlightGrid(cards: cards)
            .equatable()
    }
}

// MARK: - HighlightCard

private struct HighlightCard: View {

    let card: WeeklyHighlightGrid.CardData

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header row: icon + category name + WoW badge
            HStack(spacing: 6) {
                Image(systemName: iconName(for: card.category))
                    .font(.subheadline)
                    .foregroundStyle(iconColor(for: card.category))

                Text(categoryLabel(for: card.category))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer(minLength: 0)

                wowBadge
            }

            // Sparkline or placeholder
            if card.sparkline.isEmpty {
                placeholderRect
            } else {
                sparklineChart
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemGroupedBackground))
        )
    }

    // MARK: - WoW Badge

    @ViewBuilder
    private var wowBadge: some View {
        let pct = card.changePercent
        if abs(pct) >= 1 {
            Text("\(pct > 0 ? "↑" : "↓")\(Int(abs(pct).rounded()))%")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(pct > 0 ? Color.green : Color.red)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill((pct > 0 ? Color.green : Color.red).opacity(0.12))
                )
        }
    }

    // MARK: - Sparkline Chart

    @ViewBuilder
    private var sparklineChart: some View {
        let indexedData = card.sparkline.enumerated().map { (index: $0.offset, value: $0.element) }

        Chart(indexedData, id: \.index) { item in
            AreaMark(
                x: .value("Week", item.index),
                y: .value("Value", item.value)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [iconColor(for: card.category).opacity(0.3), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .interpolationMethod(.catmullRom)

            LineMark(
                x: .value("Week", item.index),
                y: .value("Value", item.value)
            )
            .foregroundStyle(iconColor(for: card.category))
            .interpolationMethod(.catmullRom)
            .lineStyle(StrokeStyle(lineWidth: 2))
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .frame(height: 40)
    }

    // MARK: - Placeholder Rect

    @ViewBuilder
    private var placeholderRect: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(Color(.systemGray5))
            .frame(height: 40)
    }

    // MARK: - Icon / Color Helpers

    private func iconName(for category: InsightCategory) -> String {
        switch category {
        case .feeding: return "fork.knife"
        case .sleep:   return "moon.zzz.fill"
        case .diaper:  return "drop.fill"
        case .health:  return "heart.fill"
        }
    }

    private func iconColor(for category: InsightCategory) -> Color {
        switch category {
        case .feeding: return Color("feedingColor")
        case .sleep:   return Color("sleepColor")
        case .diaper:  return Color("diaperColor")
        case .health:  return Color.red
        }
    }

    private func categoryLabel(for category: InsightCategory) -> String {
        switch category {
        case .feeding: return "수유"
        case .sleep:   return "수면"
        case .diaper:  return "기저귀"
        case .health:  return "건강"
        }
    }
}

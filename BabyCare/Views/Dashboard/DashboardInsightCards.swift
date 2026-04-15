import SwiftUI

// MARK: - DashboardInsightCards

/// 대시보드 상단 컨텍스트 인사이트 카드 섹션
struct DashboardInsightCards: View {
    let insights: [DashboardInsight]

    var body: some View {
        if insights.isEmpty { EmptyView() } else {
            VStack(alignment: .leading, spacing: 12) {
                Text(NSLocalizedString("insight.section.title", comment: ""))
                    .font(.headline)
                    .foregroundStyle(.primary)

                ForEach(insights) { insight in
                    InsightCardRow(insight: insight)
                }
            }
        }
    }
}

// MARK: - InsightCardRow

private struct InsightCardRow: View {
    let insight: DashboardInsight

    var cardColor: Color { Color(insight.colorName) }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(cardColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: insight.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(cardColor)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(insight.primaryText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                if let sub = insight.secondaryText {
                    Text(sub)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(cardColor.opacity(0.07))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel({
            var parts = [insight.primaryText]
            if let sub = insight.secondaryText { parts.append(sub) }
            return parts.joined(separator: ". ")
        }())
    }
}

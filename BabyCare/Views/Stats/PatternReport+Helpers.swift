import SwiftUI
import Charts

extension PatternReportView {
    // MARK: - Helpers

    func statItem(value: String, label: String, unit: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 2) {
                Text(value)
                    .font(.title3.bold())
                if !unit.isEmpty {
                    Text(unit)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    func trendBadge(_ trend: Trend) -> some View {
        HStack(spacing: 2) {
            Image(systemName: trend == .increasing ? "arrow.up.right" :
                    trend == .decreasing ? "arrow.down.right" : "arrow.right")
                .font(.caption2)
            Text(trend.rawValue)
                .font(.caption)
        }
        .foregroundStyle(trend == .increasing ? .orange :
                            trend == .decreasing ? .blue : .secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            (trend == .increasing ? Color.orange :
                trend == .decreasing ? Color.blue : Color.secondary).opacity(0.12)
        )
        .clipShape(Capsule())
    }

    func chipView(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(.caption2)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }

    @ViewBuilder
    func comparisonRow(current: Double, previous: Double?, unit: String, label: String) -> some View {
        if let previous {
            let delta = current - previous
            let trend: Trend = delta > 0.05 ? .increasing : delta < -0.05 ? .decreasing : .stable
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("지난주 \(String(format: "%.1f", previous))\(unit)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                trendBadge(trend)
            }
        }
    }
}

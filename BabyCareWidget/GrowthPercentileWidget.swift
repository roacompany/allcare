import WidgetKit
import SwiftUI

// MARK: - GrowthPercentileWidget

struct GrowthPercentileWidget: Widget {
    let kind = "GrowthPercentileWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BabyCareProvider()) { entry in
            GrowthPercentileWidgetView(entry: entry)
        }
        .configurationDisplayName(NSLocalizedString("widget.growthPercentile.title", comment: ""))
        .description(NSLocalizedString("widget.growthPercentile.description", comment: ""))
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - GrowthPercentileWidgetView

struct GrowthPercentileWidgetView: View {
    let entry: BabyCareEntry
    @Environment(\.widgetFamily) var family
    @Environment(\.colorScheme) var colorScheme

    private var growth: WidgetGrowthPercentile? { entry.growthPercentile }

    var body: some View {
        switch family {
        case .systemMedium:
            mediumView
        default:
            smallView
        }
    }

    // MARK: Small

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 헤더
            HStack(spacing: 4) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.caption2)
                    .foregroundStyle(Color(hex: "7B9FE8"))
                Text(NSLocalizedString("widget.growthPercentile.label", comment: ""))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Spacer()

            if let g = growth {
                // 체중
                if let kg = g.weightKg, let pct = g.weightPercentile {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Image(systemName: "scalemass.fill")
                                .font(.caption2)
                                .foregroundStyle(WidgetColors.feeding(colorScheme))
                            Text(String(format: "%.1fkg", kg))
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                        }
                        Text(
                            String(
                                format: NSLocalizedString("widget.growth.percentile.format", comment: ""),
                                Int(pct)
                            )
                        )
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }
                }

                // 키
                if let cm = g.heightCm, let pct = g.heightPercentile {
                    HStack(spacing: 4) {
                        Image(systemName: "ruler.fill")
                            .font(.caption2)
                            .foregroundStyle(WidgetColors.sleep(colorScheme))
                        Text(String(format: "%.1fcm", cm))
                            .font(.caption.weight(.semibold))
                        Text(
                            String(
                                format: NSLocalizedString("widget.growth.percentile.format", comment: ""),
                                Int(pct)
                            )
                        )
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }
                }

                if let measured = g.measuredAt {
                    Text(WidgetTimeHelper.timeAgo(measured, from: entry.date))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            } else {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.title2)
                    .foregroundStyle(Color(hex: "7B9FE8").opacity(0.4))
                Text(NSLocalizedString("widget.growth.noData", comment: ""))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(entry.babyName)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .containerBackground(for: .widget) {
            ContainerRelativeShape()
                .fill(WidgetGradient.background(colorScheme))
        }
        .widgetURL(URL(string: "babycare://health/growth"))
    }

    // MARK: Medium

    private var mediumView: some View {
        HStack(spacing: 16) {
            // Left: 성장 정보
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .foregroundStyle(Color(hex: "7B9FE8"))
                    Text(NSLocalizedString("widget.growthPercentile.label", comment: ""))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let g = growth {
                    if let kg = g.weightKg, let pct = g.weightPercentile {
                        measureRow(
                            icon: "scalemass.fill",
                            color: WidgetColors.feeding(colorScheme),
                            value: String(format: "%.1fkg", kg),
                            percentile: pct
                        )
                    }
                    if let cm = g.heightCm, let pct = g.heightPercentile {
                        measureRow(
                            icon: "ruler.fill",
                            color: WidgetColors.sleep(colorScheme),
                            value: String(format: "%.1fcm", cm),
                            percentile: pct
                        )
                    }
                    if let measured = g.measuredAt {
                        Text(
                            String(
                                format: NSLocalizedString("widget.growth.measured", comment: ""),
                                WidgetTimeHelper.timeAgo(measured, from: entry.date)
                            )
                        )
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    }
                } else {
                    Text(NSLocalizedString("widget.growth.noData", comment: ""))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(entry.babyName)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Divider()
                .overlay(WidgetColors.divider(colorScheme))

            // Right: 백분위 시각화
            VStack(alignment: .leading, spacing: 10) {
                if let g = growth {
                    if let pct = g.weightPercentile {
                        percentileBar(
                            label: NSLocalizedString("widget.growth.weight", comment: ""),
                            percentile: pct,
                            color: WidgetColors.feeding(colorScheme)
                        )
                    }
                    if let pct = g.heightPercentile {
                        percentileBar(
                            label: NSLocalizedString("widget.growth.height", comment: ""),
                            percentile: pct,
                            color: WidgetColors.sleep(colorScheme)
                        )
                    }

                    // 면책 문구
                    Text(NSLocalizedString("widget.growth.disclaimer", comment: ""))
                        .font(.system(size: 8))
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                } else {
                    Text(NSLocalizedString("widget.growth.noData.hint", comment: ""))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .containerBackground(for: .widget) {
            ContainerRelativeShape()
                .fill(WidgetGradient.background(colorScheme))
        }
        .widgetURL(URL(string: "babycare://health/growth"))
    }

    // MARK: - Components

    private func measureRow(icon: String, color: Color, value: String, percentile: Double) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(color)
                .frame(width: 14)
            Text(value)
                .font(.caption.weight(.bold))
            Text(
                String(
                    format: NSLocalizedString("widget.growth.percentile.format", comment: ""),
                    Int(percentile)
                )
            )
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }

    private func percentileBar(label: String, percentile: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(
                    String(
                        format: NSLocalizedString("widget.growth.percentile.format", comment: ""),
                        Int(percentile)
                    )
                )
                .font(.caption2.weight(.semibold))
                .foregroundStyle(color)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color.opacity(0.15))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: geo.size.width * min(percentile / 100.0, 1.0), height: 6)
                }
            }
            .frame(height: 6)
        }
    }
}

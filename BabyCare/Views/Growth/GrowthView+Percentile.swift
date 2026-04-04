import SwiftUI

extension GrowthView {

    // MARK: - Percentile Helpers

    func percentileLabel(_ p: Double) -> String {
        let rounded = Int(p.rounded())
        return "\(rounded)th"
    }

    func ageMonths(from birthDate: Date, to date: Date) -> Int {
        return max(0, min(24, Int(date.timeIntervalSince(birthDate) / (86400 * 30.4375))))
    }

    // MARK: - Velocity Indicator

    @ViewBuilder
    func velocityIndicator(_ result: GrowthVelocityResult) -> some View {
        let prevLabel = percentileLabel(result.previousPercentile)
        let currLabel = percentileLabel(result.currentPercentile)

        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                // Arrow icon
                let (iconName, iconColor): (String, Color) = {
                    switch result.changeDirection {
                    case .increasing: return ("arrow.up.circle.fill", .green)
                    case .decreasing: return ("arrow.down.circle.fill", .orange)
                    case .stable:     return ("minus.circle.fill", .secondary)
                    }
                }()

                Image(systemName: iconName)
                    .foregroundStyle(iconColor)
                    .font(.caption)

                let arrowChar: String = {
                    switch result.changeDirection {
                    case .increasing: return "↑"
                    case .decreasing: return "↓"
                    case .stable:     return "→"
                    }
                }()

                Text("지난 측정 대비 백분위 \(prevLabel) → \(currLabel) \(arrowChar)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Significant decrease banner
            if result.isSignificant && result.changeDirection == .decreasing {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Text("성장률 변화가 감지되었습니다. 소아과 상담을 권장합니다.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.orange.opacity(0.1))
                )

                Text("이 정보는 참고용이며 의학적 진단을 대체하지 않습니다.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

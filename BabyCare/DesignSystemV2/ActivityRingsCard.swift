import SwiftUI

/// Apple Watch 스타일 3 concentric activity ring (외곽: 수유 / 중간: 수면 / 내부: 기저귀).
/// Dashboard V3 (DS V2 마이그레이션) 시범 카드. summary 3카드 대체.
///
/// Target 값은 임의 default (수유 8회 / 수면 8h / 기저귀 6회).
/// 추후 PO 결정에 따라 baby 월령 기반 동적 target으로 진화.
struct ActivityRingsCard: View {
    let feedingCount: Int
    let sleepDurationSeconds: TimeInterval
    let diaperCount: Int

    private let feedingTarget: Double = 8
    private let sleepTargetHours: Double = 8
    private let diaperTarget: Double = 6

    private var feedingProgress: Double {
        min(Double(feedingCount) / feedingTarget, 1.0)
    }

    private var sleepProgress: Double {
        let hours = sleepDurationSeconds / 3600
        return min(hours / sleepTargetHours, 1.0)
    }

    private var diaperProgress: Double {
        min(Double(diaperCount) / diaperTarget, 1.0)
    }

    private var sleepDisplayText: String {
        if sleepDurationSeconds <= 0 { return "0분" }
        return sleepDurationSeconds.shortDuration
    }

    var body: some View {
        HStack(spacing: DS2.Spacing.lg) {
            ringStack
                .frame(width: 132, height: 132)

            VStack(alignment: .leading, spacing: DS2.Spacing.md) {
                metricRow(
                    name: "수유",
                    value: "\(feedingCount)회",
                    target: "/\(Int(feedingTarget))",
                    color: AppColors.feedingColor
                )
                metricRow(
                    name: "수면",
                    value: sleepDisplayText,
                    target: "/\(Int(sleepTargetHours))h",
                    color: AppColors.sleepColor
                )
                metricRow(
                    name: "기저귀",
                    value: "\(diaperCount)회",
                    target: "/\(Int(diaperTarget))",
                    color: AppColors.diaperColor
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "오늘 활동 — 수유 \(feedingCount)회 중 \(Int(feedingTarget))회 목표, " +
            "수면 \(sleepDisplayText) 중 \(Int(sleepTargetHours))시간 목표, " +
            "기저귀 \(diaperCount)회 중 \(Int(diaperTarget))회 목표"
        )
    }

    // MARK: - Rings (concentric)
    private var ringStack: some View {
        ZStack {
            ActivityRing(progress: feedingProgress, color: AppColors.feedingColor, lineWidth: 14)
            ActivityRing(progress: sleepProgress, color: AppColors.sleepColor, lineWidth: 14)
                .padding(20)
            ActivityRing(progress: diaperProgress, color: AppColors.diaperColor, lineWidth: 14)
                .padding(40)
        }
    }

    // MARK: - Metric Row
    private func metricRow(name: String, value: String, target: String, color: Color) -> some View {
        HStack(spacing: DS2.Spacing.sm) {
            Circle()
                .fill(color)
                .frame(width: 9, height: 9)
            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text(value)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(target)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer(minLength: 0)
        }
    }
}

/// 단일 progress ring — background(0.2 opacity) + foreground stroke.
private struct ActivityRing: View {
    let progress: Double
    let color: Color
    let lineWidth: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.18), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            Circle()
                .trim(from: 0, to: max(0.001, min(progress, 1.0)))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.6), value: progress)
        }
    }
}

#Preview("Activity Rings — Full Day") {
    ActivityRingsCard(feedingCount: 8, sleepDurationSeconds: 8 * 3600, diaperCount: 6)
        .padding()
}

#Preview("Activity Rings — Partial") {
    ActivityRingsCard(feedingCount: 5, sleepDurationSeconds: 4.5 * 3600, diaperCount: 3)
        .padding()
}

#Preview("Activity Rings — Empty") {
    ActivityRingsCard(feedingCount: 0, sleepDurationSeconds: 0, diaperCount: 0)
        .padding()
}

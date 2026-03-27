import SwiftUI
import WidgetKit

struct LargeWidgetView: View {
    let entry: BabyCareEntry
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            // MARK: 헤더
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(WidgetColors.feeding(colorScheme))
                        .font(.caption)
                    Text(entry.babyName)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(WidgetColors.feedingText(colorScheme))
                }
                Spacer()
                Text(entry.babyAge)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 8)

            // MARK: 오늘 요약 카드 3개
            HStack(spacing: 8) {
                summaryCard(
                    icon: "cup.and.saucer.fill",
                    color: WidgetColors.feeding(colorScheme),
                    title: "수유",
                    value: "\(entry.todayFeedingCount)회",
                    sub: entry.todayTotalMl > 0 ? "\(Int(entry.todayTotalMl))ml" : nil
                )
                summaryCard(
                    icon: "moon.zzz.fill",
                    color: WidgetColors.sleep(colorScheme),
                    title: "수면",
                    value: entry.sleepDurationFormatted,
                    sub: nil
                )
                summaryCard(
                    icon: "humidity.fill",
                    color: WidgetColors.diaper(colorScheme),
                    title: "기저귀",
                    value: "\(entry.todayDiaperCount)회",
                    sub: nil
                )
            }
            .padding(.bottom, 6)

            // MARK: 예측 바
            HStack(spacing: 4) {
                Image(systemName: entry.isFeedingOverdue ? "exclamationmark.circle.fill" : "clock.fill")
                    .font(.caption2)
                    .foregroundStyle(entry.isFeedingOverdue ? .red : WidgetColors.sleep(colorScheme))
                Text(entry.isFeedingOverdue ? "수유 시간이 지났어요!" : "다음 수유 \(entry.nextFeedingText)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(entry.isFeedingOverdue ? .red : .primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(entry.isFeedingOverdue ? Color.red.opacity(0.1) : WidgetColors.sleep(colorScheme).opacity(0.15))
            )
            .padding(.bottom, 6)

            // MARK: 오늘의 기록
            VStack(alignment: .leading, spacing: 0) {
                Text("오늘의 기록")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 4)

                if entry.recentActivities.isEmpty {
                    Text("아직 기록이 없습니다")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                } else {
                    ForEach(Array(entry.recentActivities.enumerated()), id: \.offset) { _, activity in
                        activityRow(activity)
                    }
                }
            }

            Spacer(minLength: 2)

            // MARK: 액션 버튼
            HStack(spacing: 8) {
                Link(destination: URL(string: "babycare://record/feeding")!) {
                    actionButton(icon: "cup.and.saucer.fill", label: "수유", color: WidgetColors.feeding(colorScheme))
                }
                Link(destination: URL(string: "babycare://record/diaper")!) {
                    actionButton(icon: "humidity.fill", label: "기저귀", color: WidgetColors.diaper(colorScheme))
                }
                Link(destination: URL(string: "babycare://record")!) {
                    actionButton(icon: "plus", label: "기록", color: WidgetColors.sleep(colorScheme))
                }
            }
        }
        .containerBackground(for: .widget) {
            ContainerRelativeShape()
                .fill(WidgetGradient.background(colorScheme))
        }
    }

    // MARK: - Components

    private func summaryCard(icon: String, color: Color, title: String, value: String, sub: String?) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
            if let sub {
                Text(sub)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(WidgetColors.cardBackground(colorScheme).opacity(0.8))
        )
    }

    private func activityRow(_ activity: WidgetActivity) -> some View {
        HStack(spacing: 6) {
            Image(systemName: activity.icon)
                .font(.caption2)
                .foregroundStyle(Color(hex: String(activity.colorHex.dropFirst())))
                .frame(width: 14)
            Text(activity.displayName)
                .font(.caption2.weight(.medium))
            if let detail = activity.detail {
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(WidgetTimeHelper.shortTimeAgo(activity.startTime, from: entry.date))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }

    private func actionButton(icon: String, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
            Text(label)
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundStyle(color)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(WidgetColors.cardBackground(colorScheme).opacity(0.9))
        )
    }
}

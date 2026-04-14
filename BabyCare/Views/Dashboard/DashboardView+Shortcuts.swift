import SwiftUI

extension DashboardView {
    // MARK: - Prediction

    @ViewBuilder
    var predictionSection: some View {
        if let predictionText = activityVM.nextFeedingText {
            HStack(spacing: 12) {
                Image(systemName: activityVM.isFeedingOverdue
                       ? "exclamationmark.circle.fill"
                       : "clock.fill")
                    .font(.title3)
                    .foregroundStyle(activityVM.isFeedingOverdue ? .red : feedingColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text("다음 수유 예상")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(predictionText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(activityVM.isFeedingOverdue ? .red : .primary)
                    Text(activityVM.nextFeedingSubtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(activityVM.isFeedingOverdue
                          ? Color.red.opacity(0.08)
                          : feedingColor.opacity(0.08))
            )
        } else if activityVM.todayFeedingCount == 0 {
            HStack(spacing: 12) {
                Image(systemName: "lightbulb.fill")
                    .font(.title3)
                    .foregroundStyle(feedingColor.opacity(0.6))

                VStack(alignment: .leading, spacing: 2) {
                    Text("다음 수유 예상")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("수유 기록을 추가하면 다음 수유 시간을 예측해드려요")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                Spacer()
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(feedingColor.opacity(0.04))
            )
        }
    }

    // MARK: - Summary Cards

    var summaryCardsSection: some View {
        VStack(spacing: 12) {
            feedingSummaryCard
            HStack(spacing: 12) {
                sleepSummaryCard
                diaperSummaryCard
            }

            HStack {
                NavigationLink {
                    StatsView()
                } label: {
                    HStack(spacing: 4) {
                        Text("통계")
                            .font(.caption.weight(.medium))
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                    }
                    .foregroundStyle(.secondary)
                }

                Spacer()

                NavigationLink {
                    PatternReportView()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "waveform.path.ecg")
                            .font(.caption2)
                        Text("패턴 분석")
                            .font(.caption.weight(.medium))
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                    }
                    .foregroundStyle(.purple)
                }
            }
        }
    }

    var feedingSummaryCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(feedingColor.opacity(0.2))
                    .frame(width: 48, height: 48)
                Image(systemName: "cup.and.saucer.fill")
                    .font(.title3)
                    .foregroundStyle(feedingColor)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("수유")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let last = activityVM.lastFeeding {
                    Text(last.startTime.timeAgo())
                        .font(.headline)
                        .foregroundStyle(.primary)
                } else {
                    Text("기록 없음")
                        .font(.headline)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("오늘")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(activityVM.todayFeedingCount)회")
                    .font(.title3.bold())
                    .foregroundStyle(.primary)
                if activityVM.todayTotalMl > 0 {
                    Text("\(Int(activityVM.todayTotalMl))ml")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .cardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityLabel({
            let lastText = activityVM.lastFeeding.map { "마지막 수유 \($0.startTime.timeAgo())" } ?? "수유 기록 없음"
            let mlText = activityVM.todayTotalMl > 0 ? ", \(Int(activityVM.todayTotalMl))ml" : ""
            return "수유 요약. \(lastText). 오늘 \(activityVM.todayFeedingCount)회\(mlText)"
        }())
    }

    var sleepSummaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                ZStack {
                    Circle()
                        .fill(sleepColor.opacity(0.2))
                        .frame(width: 38, height: 38)
                    Image(systemName: "moon.zzz.fill")
                        .font(.body)
                        .foregroundStyle(sleepColor)
                        .accessibilityHidden(true)
                }
                Spacer()
                Text("오늘")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("수면")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let last = activityVM.lastSleep {
                Text(last.startTime.timeAgo())
                    .font(.callout.bold())
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            } else {
                Text("기록 없음")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
            }

            Text(activityVM.todaySleepDuration > 0
                 ? activityVM.todaySleepDuration.shortDuration
                 : "0분")
                .font(.title3.bold())
                .foregroundStyle(.primary)
        }
        .cardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityLabel({
            let lastText = activityVM.lastSleep.map { "마지막 수면 \($0.startTime.timeAgo())" } ?? "수면 기록 없음"
            let durText = activityVM.todaySleepDuration > 0 ? activityVM.todaySleepDuration.shortDuration : "0분"
            return "수면 요약. \(lastText). 오늘 \(durText)"
        }())
    }

    var diaperSummaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                ZStack {
                    Circle()
                        .fill(diaperColor.opacity(0.2))
                        .frame(width: 38, height: 38)
                    Image(systemName: "humidity.fill")
                        .font(.body)
                        .foregroundStyle(diaperColor)
                        .accessibilityHidden(true)
                }
                Spacer()
                Text("오늘")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("기저귀")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let last = activityVM.lastDiaper {
                Text(last.startTime.timeAgo())
                    .font(.callout.bold())
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            } else {
                Text("기록 없음")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
            }

            Text("\(activityVM.todayDiaperCount)회")
                .font(.title3.bold())
                .foregroundStyle(.primary)
        }
        .cardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityLabel({
            let lastText = activityVM.lastDiaper.map { "마지막 기저귀 \($0.startTime.timeAgo())" } ?? "기저귀 기록 없음"
            return "기저귀 요약. \(lastText). 오늘 \(activityVM.todayDiaperCount)회"
        }())
    }

}

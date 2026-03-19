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
                    .font(.system(size: 22))
                    .foregroundStyle(feedingColor)
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
    }

    var sleepSummaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                ZStack {
                    Circle()
                        .fill(sleepColor.opacity(0.2))
                        .frame(width: 38, height: 38)
                    Image(systemName: "moon.zzz.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(sleepColor)
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
    }

    var diaperSummaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                ZStack {
                    Circle()
                        .fill(diaperColor.opacity(0.2))
                        .frame(width: 38, height: 38)
                    Image(systemName: "humidity.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(diaperColor)
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
    }


}

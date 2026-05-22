import SwiftUI

extension DashboardView {
    // MARK: - Weekly Insights Card

    @ViewBuilder
    var weeklyInsightsCard: some View {
        if !activityVM.weeklyInsights.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("이번 주 하이라이트")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                ForEach(Array(activityVM.weeklyInsights.enumerated()), id: \.element.id) { idx, insight in
                    HStack(spacing: 10) {
                        Image(systemName: insightSymbol(for: insight.category))
                            .font(.body)
                            .foregroundStyle(insightColor(for: insight.category))
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(insight.title)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                            Text(insight.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if let changePercent = insight.changePercent, abs(changePercent) >= 5 {
                            Text("\(changePercent > 0 ? "↑" : "↓")\(Int(abs(changePercent).rounded()))%")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(changePercent > 0 ? Color.green : Color.red)
                        }
                    }
                    .onAppear {
                        AnalyticsService.shared.logInsightShown(
                            metricKey: insight.metricKey,
                            category: insight.category.rawValue,
                            position: idx
                        )
                    }
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.systemGroupedBackground))
            )
            .accessibilityIdentifier("weeklyInsightsCardV1")
        }
    }

    private func insightSymbol(for category: InsightCategory) -> String {
        switch category {
        case .feeding: return "fork.knife"
        case .sleep:   return "moon.zzz.fill"
        case .diaper:  return "drop.fill"
        case .health:  return "heart.fill"
        }
    }

    private func insightColor(for category: InsightCategory) -> Color {
        switch category {
        case .feeding: return feedingColor
        case .sleep:   return sleepColor
        case .diaper:  return diaperColor
        case .health:  return Color.red
        }
    }

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

    @ViewBuilder
    var summaryCardsSection: some View {
        if FeatureFlags.designSystemV2Preview {
            VStack(alignment: .leading, spacing: 12) {
                // Apple Health Summary "Favorites" section
                HStack {
                    Text("관심 항목")
                        .font(.title3.weight(.bold))
                    Spacer()
                    NavigationLink {
                        StatsView()
                    } label: {
                        Text("전체 보기")
                            .font(.subheadline)
                            .foregroundStyle(.blue)
                    }
                }
                .padding(.top, 4)

                healthStyleFavorites
            }
        } else {
            VStack(spacing: 12) {
                feedingSummaryCard
                HStack(spacing: 12) {
                    sleepSummaryCard
                    diaperSummaryCard
                }
                statsAndPatternLinks
            }
        }
    }

    // MARK: - V3 Apple Health Favorites (list-stack 1 column)
    @ViewBuilder
    private var healthStyleFavorites: some View {
        VStack(spacing: 12) {
            NavigationLink {
                StatsView()
            } label: {
                HealthStyleFavoriteCard(
                    icon: "drop.fill",
                    title: "수유",
                    value: "\(activityVM.todayFeedingCount)",
                    unit: "회",
                    supporting: feedingSupportingText,
                    tint: AppColors.feedingColor
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                StatsView()
            } label: {
                HealthStyleFavoriteCard(
                    icon: "moon.zzz.fill",
                    title: "수면",
                    value: sleepValueText,
                    supporting: sleepSupportingText,
                    tint: AppColors.sleepColor
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                StatsView()
            } label: {
                HealthStyleFavoriteCard(
                    icon: "humidity.fill",
                    title: "기저귀",
                    value: "\(activityVM.todayDiaperCount)",
                    unit: "회",
                    supporting: diaperSupportingText,
                    tint: AppColors.diaperColor
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var feedingSupportingText: String {
        var parts: [String] = []
        if let last = activityVM.lastFeeding {
            parts.append("\(last.startTime.timeAgo())")
        }
        if activityVM.todayTotalMl > 0 {
            parts.append("\(Int(activityVM.todayTotalMl))ml")
        }
        return parts.isEmpty ? "오늘 기록 없음" : parts.joined(separator: " · ")
    }

    private var sleepValueText: String {
        let dur = activityVM.todaySleepDuration
        if dur <= 0 { return "0분" }
        return dur.shortDuration
    }

    private var sleepSupportingText: String {
        guard let last = activityVM.lastSleep else { return "오늘 기록 없음" }
        return "마지막 \(last.startTime.timeAgo())"
    }

    private var diaperSupportingText: String {
        guard let last = activityVM.lastDiaper else { return "오늘 기록 없음" }
        return "마지막 \(last.startTime.timeAgo())"
    }

    private var statsAndPatternLinks: some View {
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
        .summaryCardStyle(tint: feedingColor)
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
        .summaryCardStyle(tint: sleepColor)
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
        .summaryCardStyle(tint: diaperColor)
        .accessibilityElement(children: .combine)
        .accessibilityLabel({
            let lastText = activityVM.lastDiaper.map { "마지막 기저귀 \($0.startTime.timeAgo())" } ?? "기저귀 기록 없음"
            return "기저귀 요약. \(lastText). 오늘 \(activityVM.todayDiaperCount)회"
        }())
    }

}

// MARK: - Summary Card Style (DS2 dual-mode)

extension View {
    /// FeatureFlag 분기:
    /// - V2 (designSystemV2Preview=true): 활동색 12% opacity tint 배경 (DS2 토큰)
    /// - V1: 기존 `cardStyle()` (.regularMaterial)
    @ViewBuilder
    func summaryCardStyle(tint: Color) -> some View {
        if FeatureFlags.designSystemV2Preview {
            self
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                .background(tint.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 14))
        } else {
            self.cardStyle()
        }
    }
}

import Foundation
import SwiftUI

@MainActor
extension ActivityViewModel {
    // MARK: - Activity Reminder

    func scheduleActivityReminderIfNeeded(type: Activity.ActivityType, babyName: String) {
        guard let rule = ActivityReminderSettings.rule(for: type), rule.enabled else { return }
        NotificationService.shared.scheduleActivityReminder(
            type: type, babyName: babyName, afterMinutes: rule.intervalMinutes
        )
    }

    // MARK: - Widget Data Sync

    func syncWidgetData(babyName: String, babyAge: String) {
        let interval = Int(NotificationSettings.feedingIntervalHours * 60)

        // 오늘 요약 데이터 — lastFeeding/lastSleep/lastDiaper 프로퍼티 재사용
        let sleepMinutes = Int(todaySleepDuration / 60)
        let sleepDurationText = lastSleep?.durationText

        // 최근 5개 활동 → WidgetActivity 변환
        let recent = todayActivities
            .sorted { $0.startTime > $1.startTime }
            .prefix(5)
            .map { activity -> WidgetActivity in
                let detail: String? = activity.durationText ?? activity.amountText
                let colorHex: String
                switch activity.type.category {
                case .feeding: colorHex = "#FF9FB5"
                case .sleep:   colorHex = "#7B9FE8"
                case .diaper:  colorHex = "#85C1A3"
                case .health:  colorHex = "#F4845F"
                }
                return WidgetActivity(
                    typeRaw: activity.type.rawValue,
                    displayName: activity.type.displayName,
                    icon: activity.type.icon,
                    colorHex: colorHex,
                    startTime: activity.startTime,
                    detail: detail
                )
            }

        WidgetDataStore.update(
            babyName: babyName,
            babyAge: babyAge,
            lastFeeding: lastFeeding?.startTime,
            lastFeedingType: lastFeeding?.type.displayName,
            lastSleep: lastSleep?.startTime,
            lastDiaper: lastDiaper?.startTime,
            feedingIntervalMinutes: interval,
            todayFeedingCount: todayFeedingCount,
            todaySleepMinutes: sleepMinutes,
            todayDiaperCount: todayDiaperCount,
            todayTotalMl: todayTotalMl,
            recentActivities: Array(recent),
            lastSleepDuration: sleepDurationText
        )
    }
}

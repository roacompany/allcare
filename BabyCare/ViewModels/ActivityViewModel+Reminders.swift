import Foundation
import SwiftUI

@MainActor
extension ActivityViewModel {
    // MARK: - Activity Reminder

    func scheduleActivityReminderIfNeeded(type: Activity.ActivityType, babyName: String) {
        // 복귀 넛지 (이탈 방지 P0-2): 모든 저장 = 침묵 타이머 리셋.
        // 활동별 리마인더 규칙(아래 guard)과 무관하게 항상 갱신한다.
        NotificationService.shared.scheduleReturnNudge()

        // 투약 알림 인라인 제안 (B2): 규칙 OFF + 미제안이면 생애 1회 제안
        if type == .medication,
           MedicationReminderPromptPolicy.shouldOffer(
               ruleEnabled: ActivityReminderSettings.rule(for: .medication)?.enabled ?? false,
               alreadyPrompted: MedicationReminderPromptPolicy.alreadyPrompted
           ) {
            medicationPromptPending = true
        }

        guard let rule = ActivityReminderSettings.rule(for: type), rule.enabled else { return }
        NotificationService.shared.scheduleActivityReminder(
            type: type, babyName: babyName, afterMinutes: rule.intervalMinutes
        )

        if (type == .feedingBreast || type == .feedingBottle),
           ActivityReminderSettings.feedingOverdueAlertEnabled,
           let predictedTime = nextFeedingEstimate {
            NotificationService.shared.scheduleFeedingOverdueAlert(babyName: babyName, predictedTime: predictedTime)
        }
    }

    /// 투약 알림 제안 소비 (켜기/나중에 무관 1회 — 재노출 방지)
    func dismissMedicationPrompt() {
        medicationPromptPending = false
        MedicationReminderPromptPolicy.markPrompted()
    }

    /// 제안 수락: 투약 규칙 ON + 이번 투약 기준 체인 즉시 예약
    func enableMedicationReminder(babyName: String) {
        var rule = ActivityReminderSettings.rule(for: .medication)
            ?? ActivityReminderRule(activityType: Activity.ActivityType.medication.rawValue, enabled: true, intervalMinutes: 480)
        rule.enabled = true
        ActivityReminderSettings.updateRule(rule)
        NotificationService.shared.scheduleActivityReminder(type: .medication, babyName: babyName, afterMinutes: rule.intervalMinutes)
    }

    // MARK: - Widget Data Sync

    func syncWidgetData(babyName: String, babyAge: String) {
        // 월령별 기본 간격 또는 사용자 설정값 사용
        let defaultInterval = AppConstants.feedingIntervalHours(ageInMonths: babyAgeInMonths)
        let userInterval = NotificationSettings.feedingIntervalHours
        // 사용자가 명시적으로 변경하지 않았으면 (기본값 3시간 그대로면) 월령별 값 사용
        let effectiveHours = (userInterval == AppConstants.defaultFeedingIntervalHours) ? defaultInterval : userInterval
        let interval = Int(effectiveHours * 60)

        // 오늘 요약 데이터 — lastFeeding/lastSleep/lastDiaper 프로퍼티 재사용
        let sleepMinutes = Int(todaySleepDuration / 60)
        let sleepDurationText = lastSleep?.durationText

        // 최근 5개 활동 → WidgetActivity 변환
        let recent = todayActivities
            // 유축(strip 도배 방지) + .unknown(forward-compat 센티넬, 구버전엔 표시 불가)은 위젯 최근활동 strip 제외
            .filter { $0.type.category != .pumping && $0.type.category != .unknown }
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
                case .pumping: colorHex = "#B56FD1"   // 보라/자두 — pumpingColor asset(light)과 일치
                case .unknown: colorHex = "#8E8E93"   // 중립 회색 (filter로 도달 불가하나 exhaustive 보장)
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

        // Phase 2: 낮잠 예측 계산 (오늘 낮잠 활동에서 간격 추정)
        let napPrediction = computeNapPrediction()

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
            lastSleepDuration: sleepDurationText,
            nextFeedingEstimate: nextFeedingEstimate,
            napPrediction: napPrediction
        )
    }

    // MARK: - Nap Prediction

    /// 오늘 낮잠 활동에서 평균 낮잠 간격을 계산하여 다음 낮잠 예상 시각을 반환합니다.
    private func computeNapPrediction() -> WidgetNapPrediction {
        let calendar = Calendar.current
        // 낮잠: 06~18시 시작 수면 활동
        let naps = todayActivities
            .filter { act in
                act.type == .sleep && {
                    let hour = calendar.component(.hour, from: act.startTime)
                    return hour >= 6 && hour < 18
                }()
            }
            .sorted { $0.startTime < $1.startTime }

        let lastNapTime = naps.last?.startTime

        // 낮잠 간격: 최근 2개 낮잠의 간격 (없으면 월령별 기본 90분)
        let napIntervalMinutes: Int
        if naps.count >= 2 {
            let gapSeconds = naps[naps.count - 1].startTime.timeIntervalSince(naps[naps.count - 2].startTime)
            let gapMinutes = Int(gapSeconds / 60)
            napIntervalMinutes = (gapMinutes > 30 && gapMinutes < 240) ? gapMinutes : 120
        } else {
            // 월령 기반 기본값: 3개월 미만 90분, 이후 120분
            napIntervalMinutes = babyAgeInMonths < 3 ? 90 : 120
        }

        let nextNapTime = lastNapTime.map { $0.addingTimeInterval(Double(napIntervalMinutes) * 60) }

        return WidgetNapPrediction(
            lastNapTime: lastNapTime,
            nextNapTime: nextNapTime,
            napIntervalMinutes: napIntervalMinutes
        )
    }
}

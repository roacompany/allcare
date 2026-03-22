import Foundation
import SwiftUI

@MainActor
extension ActivityViewModel {
    // MARK: - Save Activity (낙관적 업데이트 + 롤백)

    func saveActivity(userId: String, babyId: String, type: Activity.ActivityType) async {
        // 시작시간 결정 (타이머 or 수동)
        let startTime = isTimeAdjusted ? manualStartTime : Date()

        // 중복 체크
        if hasDuplicateRecord(type: type, startTime: startTime) {
            pendingDuplicateSave = { [weak self] in
                await self?.performSaveActivity(userId: userId, babyId: babyId, type: type)
            }
            showDuplicateWarning = true
            return
        }

        // 실제 저장
        await performSaveActivity(userId: userId, babyId: babyId, type: type)
    }

    func performSaveActivity(userId: String, babyId: String, type: Activity.ActivityType) async {
        var activity = Activity(babyId: babyId, type: type)

        let timerBelongsToMe = isTimerRunning && activeTimerType == type
        // stopTimer() 호출 전 수동 조정 여부 캡처 (stopTimer가 isTimeAdjusted를 덮어쓰기 전)
        let wasManuallyAdjusted = isTimeAdjusted

        switch type {
        case .feedingBreast:
            if timerBelongsToMe {
                let duration = stopTimer()
                activity.duration = duration
                activity.startTime = Date().addingTimeInterval(-duration)
            }
            activity.side = selectedSide

        case .feedingBottle:
            guard isAmountValid else {
                errorMessage = "수유량을 올바르게 입력해주세요. (1~500ml)"
                return
            }
            if timerBelongsToMe {
                let duration = stopTimer()
                activity.duration = duration
                activity.startTime = Date().addingTimeInterval(-duration)
            }
            activity.amount = Double(amount)

        case .feedingSolid:
            activity.foodName = foodName.isEmpty ? nil : foodName
            activity.foodAmount = foodAmount.isEmpty ? nil : foodAmount
            activity.foodReaction = foodReaction

        case .feedingSnack:
            activity.foodName = foodName.isEmpty ? nil : foodName
            activity.foodAmount = foodAmount.isEmpty ? nil : foodAmount

        case .sleep:
            if timerBelongsToMe {
                let duration = stopTimer()
                activity.duration = duration
                activity.startTime = Date().addingTimeInterval(-duration)
                activity.endTime = Date()
            }
            activity.sleepQuality = sleepQuality
            activity.sleepMethod = sleepMethod

        case .diaperWet, .diaperDirty, .diaperBoth:
            if type == .diaperDirty || type == .diaperBoth {
                activity.stoolColor = stoolColor
                activity.stoolConsistency = stoolConsistency
                activity.hasRash = hasRash ? true : nil
            }

        case .temperature:
            guard isTemperatureValid else {
                errorMessage = "체온을 올바르게 입력해주세요. (34.0~43.0°C)"
                return
            }
            activity.temperature = Double(temperatureInput)

        case .medication:
            activity.medicationName = medicationName.isEmpty ? nil : medicationName
            activity.medicationDosage = medicationDosage.isEmpty ? nil : medicationDosage

        case .bath:
            if timerBelongsToMe {
                let duration = stopTimer()
                activity.duration = duration
                activity.startTime = Date().addingTimeInterval(-duration)
            }
        }

        // 수동 시간 조정 (타이머보다 우선, 타이머 직접 저장 경로와 분리)
        if wasManuallyAdjusted {
            activity.startTime = manualStartTime
            if let endTime = manualEndTime {
                activity.endTime = endTime
                activity.duration = endTime.timeIntervalSince(manualStartTime)
            }
        }

        // 수면 24시간 상한 검증
        if type == .sleep, let duration = activity.duration, duration > 86400 {
            errorMessage = "수면 시간이 24시간을 초과합니다. 시간을 확인해주세요."
            return
        }

        if !note.isEmpty {
            activity.note = note
        }

        // 낙관적 업데이트: 먼저 UI 반영
        todayActivities.insert(activity, at: 0)
        let rollbackIndex = 0

        do {
            try await firestoreService.saveActivity(activity, userId: userId)
            deriveLatestActivities()
            scheduleActivityReminderIfNeeded(type: type, babyName: "아기")
            resetForm()
        } catch {
            // 롤백: 실패 시 UI에서 제거
            if rollbackIndex < todayActivities.count, todayActivities[rollbackIndex].id == activity.id {
                todayActivities.remove(at: rollbackIndex)
            }
            errorMessage = "기록 저장에 실패했습니다: \(error.localizedDescription)"
        }
    }

    /// QuickInputSheet에서 미리 구성된 Activity 저장 (체온/투약/분유 등)
    func savePrebuiltActivity(_ activity: Activity, userId: String) async {
        todayActivities.insert(activity, at: 0)

        do {
            try await firestoreService.saveActivity(activity, userId: userId)
            deriveLatestActivities()
            scheduleActivityReminderIfNeeded(type: activity.type, babyName: "아기")
        } catch {
            todayActivities.removeAll { $0.id == activity.id }
            errorMessage = "기록 저장에 실패했습니다."
        }
    }

    func quickSave(userId: String, babyId: String, type: Activity.ActivityType) async {
        var activity = Activity(babyId: babyId, type: type)

        // 빠른 기록에서도 최소한의 기본값 설정
        if type == .feedingBreast {
            activity.side = .left
        }

        todayActivities.insert(activity, at: 0)

        do {
            try await firestoreService.saveActivity(activity, userId: userId)
            deriveLatestActivities()
            scheduleActivityReminderIfNeeded(type: type, babyName: "아기")
        } catch {
            todayActivities.removeAll { $0.id == activity.id }
            errorMessage = "기록 저장에 실패했습니다."
        }
    }

    func updateActivity(_ activity: Activity, userId: String) async {
        guard let index = todayActivities.firstIndex(where: { $0.id == activity.id }) else { return }

        let backup = todayActivities[index]
        todayActivities[index] = activity

        do {
            try await firestoreService.saveActivity(activity, userId: userId)
        } catch {
            todayActivities[index] = backup
            errorMessage = "기록 수정에 실패했습니다."
        }
    }

    func deleteActivity(_ activity: Activity, userId: String) async {
        let backup = todayActivities
        todayActivities.removeAll { $0.id == activity.id }

        do {
            try await firestoreService.deleteActivity(activity.id, userId: userId, babyId: activity.babyId)
            deriveLatestActivities()
            syncWidgetData(babyName: currentBabyName, babyAge: "")
        } catch {
            todayActivities = backup
            errorMessage = "기록 삭제에 실패했습니다."
        }
    }

    func resetForm() {
        selectedSide = .left
        amount = ""
        temperatureInput = ""
        medicationName = ""
        note = ""
        errorMessage = nil
        foodName = ""
        foodAmount = ""
        foodReaction = nil
        stoolColor = nil
        stoolConsistency = nil
        hasRash = false
        sleepQuality = nil
        sleepMethod = nil
        medicationDosage = ""
        manualStartTime = Date()
        manualEndTime = nil
        isTimeAdjusted = false
    }
}

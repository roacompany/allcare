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

        guard applyTypeFields(to: &activity, type: type, timerBelongsToMe: timerBelongsToMe) else { return }

        applyManualTimeAdjustment(to: &activity, wasManuallyAdjusted: wasManuallyAdjusted)

        guard validateActivity(activity, type: type, wasManuallyAdjusted: wasManuallyAdjusted) else { return }

        if !note.isEmpty { activity.note = note }

        // 낙관적 업데이트: 먼저 UI 반영
        todayActivities.insert(activity, at: 0)

        do {
            try await firestoreService.saveActivity(activity, userId: userId)
            deriveLatestActivities()
            scheduleActivityReminderIfNeeded(type: type, babyName: "아기")
            if type == .temperature && isFeverTrendDetected {
                NotificationService.shared.scheduleTemperatureTrendAlert(babyName: currentBabyName)
            }
            resetForm()
        } catch {
            enqueueOfflineActivity(activity, userId: userId, babyId: babyId)
            deriveLatestActivities()
            resetForm()
            errorMessage = "오프라인 저장됨 — 연결 시 자동 동기화"
        }
    }

    // MARK: - performSaveActivity Helpers

    /// 각 activity type에 맞는 필드 적용. 유효성 실패 시 false 반환.
    private func applyTypeFields(
        to activity: inout Activity,
        type: Activity.ActivityType,
        timerBelongsToMe: Bool
    ) -> Bool {
        switch type {
        case .feedingBreast:
            applyTimerDuration(to: &activity, timerBelongsToMe: timerBelongsToMe, includeEndTime: false)
            activity.side = selectedSide

        case .feedingBottle:
            guard isAmountValid else {
                errorMessage = "수유량을 올바르게 입력해주세요. (1~500ml)"
                return false
            }
            applyTimerDuration(to: &activity, timerBelongsToMe: timerBelongsToMe, includeEndTime: false)
            activity.amount = Double(amount)

        case .feedingSolid:
            activity.foodName = foodName.isEmpty ? nil : foodName
            activity.foodAmount = foodAmount.isEmpty ? nil : foodAmount
            activity.foodReaction = foodReaction

        case .feedingSnack:
            activity.foodName = foodName.isEmpty ? nil : foodName
            activity.foodAmount = foodAmount.isEmpty ? nil : foodAmount

        case .sleep:
            applyTimerDuration(to: &activity, timerBelongsToMe: timerBelongsToMe, includeEndTime: true)
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
                return false
            }
            activity.temperature = Double(temperatureInput)

        case .medication:
            activity.medicationName = medicationName.isEmpty ? nil : medicationName
            activity.medicationDosage = medicationDosage.isEmpty ? nil : medicationDosage

        case .bath:
            applyTimerDuration(to: &activity, timerBelongsToMe: timerBelongsToMe, includeEndTime: false)
        }
        return true
    }

    /// 타이머 경과시간을 activity에 적용
    private func applyTimerDuration(to activity: inout Activity, timerBelongsToMe: Bool, includeEndTime: Bool) {
        guard timerBelongsToMe else { return }
        let duration = stopTimer()
        activity.duration = duration
        activity.startTime = Date().addingTimeInterval(-duration)
        if includeEndTime { activity.endTime = Date() }
    }

    /// 수동 시간 조정 적용 (타이머보다 우선)
    private func applyManualTimeAdjustment(to activity: inout Activity, wasManuallyAdjusted: Bool) {
        guard wasManuallyAdjusted else { return }
        activity.startTime = manualStartTime
        if let endTime = manualEndTime {
            activity.endTime = endTime
            activity.duration = endTime.timeIntervalSince(manualStartTime)
        }
    }

    /// 저장 전 공통 유효성 검사. 실패 시 false 반환.
    private func validateActivity(_ activity: Activity, type: Activity.ActivityType, wasManuallyAdjusted: Bool) -> Bool {
        if let duration = activity.duration, duration < 1, !wasManuallyAdjusted {
            errorMessage = "최소 1초 이상 기록해주세요."
            return false
        }
        if type == .sleep, let duration = activity.duration, duration > 86400 {
            errorMessage = "수면 시간이 24시간을 초과합니다. 시간을 확인해주세요."
            return false
        }
        return true
    }

    /// 오프라인 큐에 activity 저장
    private func enqueueOfflineActivity(_ activity: Activity, userId: String, babyId: String) {
        let collectionPath = "\(FirestoreCollections.users)/\(userId)/\(FirestoreCollections.babies)/\(babyId)/\(FirestoreCollections.activities)"
        let jsonData = try? JSONEncoder().encode(activity)
        let pendingOp = PendingOperation(
            id: UUID().uuidString,
            timestamp: Date(),
            type: .create,
            collectionPath: collectionPath,
            documentId: activity.id,
            jsonData: jsonData
        )
        OfflineQueue.shared.enqueue(pendingOp)
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

import Foundation
import SwiftUI

@MainActor
extension ActivityViewModel {
    // MARK: - Save Activity (낙관적 업데이트 + 롤백)

    /// 활동 저장.
    /// - Parameter userId: 데이터 저장 path (가족 공유 시 owner uid). babyVM.dataUserId() 사용.
    /// - Parameter currentUserId: 배지 부여 대상 본인 uid. 호출자(authVM.currentUserId).
    ///   (H-4 회귀 fix: 배지는 항상 본인 path에 저장 — 가족 공유 시 owner 배지 격리)
    func saveActivity(userId: String, currentUserId: String, babyId: String, type: Activity.ActivityType) async {
        // 중복 체크는 타이머 stop 전 기준시간으로 (원본 동일 — 실행 중 타이머는 '지금'으로 판정).
        let dupCheckStart = isTimeAdjusted ? manualStartTime : Date()
        if hasDuplicateRecord(type: type, startTime: dupCheckStart) {
            pendingDuplicateSave = { [weak self] in
                guard let self else { return }
                // 확정 시점에 타이머 stop (원본 performSaveActivity와 동일 — 취소 시 타이머 유지)
                let draft = self.makeDraft(type: type, babyId: babyId)
                _ = await self.commit(draft: draft, userId: userId, currentUserId: currentUserId)
                if self.errorMessage == nil { self.resetForm() }
            }
            showDuplicateWarning = true
            return
        }

        let draft = makeDraft(type: type, babyId: babyId)
        _ = await commit(draft: draft, userId: userId, currentUserId: currentUserId)
        if errorMessage == nil { resetForm() }
    }

    // MARK: - Unified Pipeline (P0) — 단일 저장 경로

    /// 현재 폼 상태를 순수 스냅샷(ActivityDraft)으로 캡처.
    /// 타이머가 이 타입이면 stopTimer()로 duration 확정(부수효과), 수동 시간조정을 타이머보다 우선 반영.
    /// (현행 applyTimerDuration / applyManualTimeAdjustment 로직 이관)
    func makeDraft(type: Activity.ActivityType, babyId: String) -> ActivityDraft {
        var d = ActivityDraft(babyId: babyId, type: type)
        let timerBelongsToMe = isTimerRunning && activeTimerType == type
        let wasManuallyAdjusted = isTimeAdjusted   // stopTimer 전 캡처(stopTimer가 isTimeAdjusted를 덮어씀)

        if timerBelongsToMe {
            let duration = stopTimer()
            d.duration = duration
            d.startTime = Date().addingTimeInterval(-duration)
            if type == .sleep { d.endTime = Date() }   // 원본: sleep만 includeEndTime:true
        }

        if wasManuallyAdjusted {                        // 수동 조정이 타이머보다 우선
            d.startTime = manualStartTime
            d.wasManuallyAdjusted = true
            if let end = manualEndTime {
                d.endTime = end
                d.duration = end.timeIntervalSince(manualStartTime)
            }
        } else if !timerBelongsToMe {
            d.startTime = isTimeAdjusted ? manualStartTime : Date()
        }

        d.side = selectedSide
        d.amountText = amount
        d.feedingContent = selectedFeedingContent
        d.pumpStorage = selectedPumpStorage
        d.foodName = foodName
        d.foodAmount = foodAmount
        d.foodReaction = foodReaction
        d.temperatureText = temperatureInput
        d.medicationName = medicationName
        d.medicationDosage = medicationDosage
        d.sleepQuality = sleepQuality
        d.sleepMethod = sleepMethod
        d.stoolColor = stoolColor
        d.stoolConsistency = stoolConsistency
        d.hasRash = hasRash
        d.note = note
        return d
    }

    /// 단일 저장 진입. draft 검증 → 성공 시 persist. 저장된 activity 반환(실패 시 nil + errorMessage).
    @discardableResult
    func commit(draft: ActivityDraft, userId: String, currentUserId: String) async -> Activity? {
        errorMessage = nil
        switch ActivityDraftBuilder.build(draft) {
        case .failure(let err):
            if err == .unknownType { logUnknownSaveBlocked() } else { errorMessage = err.message }
            return nil
        case .success(var activity):
            activity.createdBy = currentUserId
            let ok = await persist(activity, userId: userId, currentUserId: currentUserId)
            return ok ? activity : nil
        }
    }

    /// 공용 저장 꼬리 — 낙관적 insert → Firestore save → 부수효과, 실패 시 오프라인 큐(전 경로 일관).
    /// 큐잉 = 사용자 관점 저장 성공이므로 true 반환.
    @discardableResult
    private func persist(_ activity: Activity, userId: String, currentUserId: String) async -> Bool {
        todayActivities.insert(activity, at: 0)   // 낙관적 업데이트
        do {
            try await firestoreService.saveActivity(activity, userId: userId)
            deriveLatestActivities()
            scheduleActivityReminderIfNeeded(type: activity.type, babyName: "아기")
            if activity.type == .temperature, registerTemperature(activity) {
                NotificationService.shared.scheduleTemperatureTrendAlert(babyName: currentBabyName)
            }
            await evaluateBadgesIfNeeded(type: activity.type, babyId: activity.babyId, currentUserId: currentUserId, at: activity.startTime)
            return true
        } catch {
            enqueueOfflineActivity(activity, userId: userId, babyId: activity.babyId)
            deriveLatestActivities()
            InfoToastCenter.shared.offlineSaved()
            return true   // 큐잉됨 = 사용자 관점 성공
        }
    }

    /// .unknown 저장 시도 진단 로깅 (forward-compat 센티넬은 정상 흐름에서 도달 불가 — 도달 시 버그 신호)
    private func logUnknownSaveBlocked() {
        AppLogger.firestore.warning("ActivityType.unknown 저장 차단 — read-only 센티넬은 영속 불가 (forward-compat)")
    }

    /// 오프라인 큐에 activity 저장
    private func enqueueOfflineActivity(_ activity: Activity, userId: String, babyId: String) {
        // 오프라인 큐는 saveActivity 가드를 우회하는 별도 쓰기 경로 → .unknown 차단 (데이터 손실 방지)
        guard activity.type != .unknown else { return logUnknownSaveBlocked() }
        let collectionPath = FirestoreCollections.babyChildPath(userId: userId, babyId: babyId, collection: FirestoreCollections.activities)
        if !OfflineQueue.shared.enqueueSave(activity, collectionPath: collectionPath, documentId: activity.id) {
            // L3: 인코딩 실패 시 적재 생략 — 로깅으로 데이터 손실 가시화
            AppLogger.firestore.error("오프라인 큐 인코딩 실패 — activity \(activity.id) 큐잉 누락")
        }
    }

    /// QuickInputSheet에서 미리 구성된 Activity 저장 (체온/투약/분유 등) — 공용 persist 꼬리 경유(오프라인 큐 획득).
    func savePrebuiltActivity(_ activity: Activity, userId: String, currentUserId: String) async {
        guard activity.type != .unknown else { return logUnknownSaveBlocked() }
        errorMessage = nil
        var a = activity
        a.createdBy = currentUserId
        _ = await persist(a, userId: userId, currentUserId: currentUserId)
    }

    func quickSave(userId: String, currentUserId: String, babyId: String, type: Activity.ActivityType) async {
        // 빠른 기록: 최소 draft로 commit (오프라인 큐·부수효과 전 경로 일관 — P0).
        var draft = ActivityDraft(babyId: babyId, type: type)
        if type == .feedingBreast { draft.side = .left }   // 모유수유 방향 기본값 보존
        _ = await commit(draft: draft, userId: userId, currentUserId: currentUserId)
    }

    // MARK: - Badge Hook

    /// 저장 성공 후 BadgeEvaluator 호출 (배지 대상 아닌 타입은 no-op).
    /// 배지는 항상 본인(currentUserId) path에 저장 — 가족 공유 시 owner 배지 격리.
    private func evaluateBadgesIfNeeded(type: Activity.ActivityType, babyId: String, currentUserId: String, at date: Date) async {
        guard let kind = BadgeEvaluator.eventKind(for: type) else { return }
        let event = BadgeEvaluator.Event(kind: kind, babyId: babyId, at: date)
        let earned = await BadgeEvaluator().evaluate(event: event, userId: currentUserId)
        AppState.shared.badgePresenter.enqueue(earned)
        await noteRecordsMilestoneIfEligible(currentUserId: currentUserId)
    }

    /// 누적 핵심 활동 기록이 임계값(20)을 넘으면 앱 평가 대기 신호. 이미 소진됐으면 stats fetch도 생략.
    private func noteRecordsMilestoneIfEligible(currentUserId: String) async {
        guard !AppReviewPromptService.shared.isConsumed else { return }
        let stats = try? await firestoreService.fetchStats(userId: currentUserId)
        guard AppReviewPromptService.coreActivityTotal(stats) >= AppReviewPromptService.recordsMilestoneThreshold else { return }
        AppReviewPromptService.shared.noteTrigger(.recordsMilestone)
    }

    func updateActivity(_ activity: Activity, userId: String) async {
        // .unknown(forward-compat 센티넬)은 편집/영속 불가 — optimisticReplace 진입 전 차단해
        // 팬텀 에딧(저장 실패가 성공처럼 보이는 in-memory 발산) + 오프라인 큐 우회 방지.
        guard activity.type != .unknown else { return logUnknownSaveBlocked() }

        if let original = todayActivities.first(where: { $0.id == activity.id }) {
            // 대시보드(오늘) 경로: 낙관적 in-memory 교체 + 저장 + 실패 시 롤백.
            if let error = await optimisticReplace(
                in: \.todayActivities, original: original, with: activity,
                save: { try await self.firestoreService.saveActivity(activity, userId: userId) }
            ) {
                errorMessage = "기록 수정에 실패했습니다."
                _ = error
            }
        } else {
            // 캘린더(다른 날짜) 경로: todayActivities 에 없는 과거/타 날짜 기록도 Firestore 에 반드시 저장.
            // (기존엔 여기서 early-return 해 저장이 통째 누락 → 종료시간 등 수정이 reload 시 원복됐다.)
            do {
                try await firestoreService.saveActivity(activity, userId: userId)
            } catch {
                errorMessage = "기록 수정에 실패했습니다."
            }
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
        selectedFeedingContent = .formula
        selectedPumpStorage = .fridge
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

    // MARK: - 유축 재고 (P5)

    /// 재고 화면용 — 최근 6개월 짜기/유축먹이기 활동 로드(freezer 장기 배치 포함).
    func loadPumpInventory(userId: String, babyId: String) async {
        let sixMonthsAgo = Date().addingTimeInterval(-6 * 30 * AppConstants.secondsPerDay)
        do {
            let all = try await firestoreService.fetchActivities(userId: userId, babyId: babyId, from: sixMonthsAgo, to: Date())
            inventoryActivities = all.filter { $0.type == .feedingPumping || $0.isBreastMilkBottle }
        } catch {
            logSilent("유축 재고를 불러오지 못했습니다", error: error, logger: AppLogger.firestore)
        }
    }

    /// 짜기 배치 폐기 — pumpDiscarded=true 저장(재고서 제외). 낙관적 업데이트 + 실패 롤백.
    func discardPumpBatch(_ activityId: String, userId: String) async {
        guard let idx = inventoryActivities.firstIndex(where: { $0.id == activityId }) else { return }
        let original = inventoryActivities[idx]
        var activity = original
        activity.pumpDiscarded = true
        inventoryActivities[idx] = activity   // 낙관적
        do {
            try await firestoreService.saveActivity(activity, userId: userId)
        } catch {
            inventoryActivities[idx] = original
            errorMessage = "재고 수정에 실패했습니다."
        }
    }
}

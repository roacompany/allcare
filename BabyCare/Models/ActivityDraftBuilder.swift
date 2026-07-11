import Foundation

/// ActivityDraft(순수 스냅샷) → 검증된 Activity 변환. 부수효과 없음(테스트 용이).
/// 현행 ActivityViewModel+Save 의 applyTypeFields / validateActivity 로직 이관.
enum ActivityDraftBuilder {
    nonisolated static func build(_ draft: ActivityDraft) -> Result<Activity, RecordValidationError> {
        guard draft.type != .unknown else { return .failure(.unknownType) }

        var a = Activity(babyId: draft.babyId, type: draft.type)
        a.startTime = draft.startTime
        if let end = draft.endTime { a.endTime = end }
        if let dur = draft.duration { a.duration = dur }

        if let err = applyTypeFields(draft, to: &a) { return .failure(err) }
        if let err = validate(draft, activity: a) { return .failure(err) }

        let trimmed = draft.note.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { a.note = trimmed }
        return .success(a)
    }

    /// 타입별 필드 적용. 검증 실패 시 에러 반환(성공 nil). 현행 applyTypeFields 이관.
    /// default: 없이 exhaustive 유지 — 신규 ActivityType이 조용히 누락되지 않도록(swift-conventions).
    private nonisolated static func applyTypeFields(_ draft: ActivityDraft, to a: inout Activity) -> RecordValidationError? {
        switch draft.type {
        case .feedingBreast:
            a.side = draft.side ?? .left
        case .feedingBottle:
            guard let ml = Double(draft.amountText), ml > 0, ml <= 500 else { return .invalidAmount(isPumping: false) }
            a.amount = ml
            a.feedingContent = draft.feedingContent
        case .feedingPumping:
            guard let ml = Double(draft.amountText), ml > 0, ml <= 500 else { return .invalidAmount(isPumping: true) }
            a.amount = ml
            a.side = draft.side
        case .feedingSolid:
            a.foodName = draft.foodName.isEmpty ? nil : draft.foodName
            a.foodAmount = draft.foodAmount.isEmpty ? nil : draft.foodAmount
            a.foodReaction = draft.foodReaction
        case .feedingSnack:
            a.foodName = draft.foodName.isEmpty ? nil : draft.foodName
            a.foodAmount = draft.foodAmount.isEmpty ? nil : draft.foodAmount
        case .sleep:
            a.sleepQuality = draft.sleepQuality
            a.sleepMethod = draft.sleepMethod
        case .diaperWet:
            break
        case .diaperDirty, .diaperBoth:
            a.stoolColor = draft.stoolColor
            a.stoolConsistency = draft.stoolConsistency
            a.hasRash = draft.hasRash ? true : nil
        case .temperature:
            guard let t = Double(draft.temperatureText), t >= 34.0, t <= 43.0 else { return .invalidTemperature }
            a.temperature = t
        case .medication:
            a.medicationName = draft.medicationName.isEmpty ? nil : draft.medicationName
            a.medicationDosage = draft.medicationDosage.isEmpty ? nil : draft.medicationDosage
        case .bath:
            break
        case .unknown:
            return .unknownType
        }
        return nil
    }

    /// 저장 전 공통 검증(최소 1초·수면 24h). 현행 validateActivity 이관.
    private nonisolated static func validate(_ draft: ActivityDraft, activity a: Activity) -> RecordValidationError? {
        if let dur = a.duration, dur < 1, !draft.wasManuallyAdjusted { return .tooShort }
        if draft.type == .sleep, let dur = a.duration, dur > AppConstants.secondsPerDay { return .sleepTooLong }
        return nil
    }
}

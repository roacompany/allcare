import Foundation

/// ActivityDraft(순수 스냅샷) → 검증된 Activity 변환. 부수효과 없음(테스트 용이).
/// 현행 ActivityViewModel+Save 의 applyTypeFields / validateActivity / applyManualTimeAdjustment 로직 이관.
enum ActivityDraftBuilder {
    nonisolated static func build(_ draft: ActivityDraft) -> Result<Activity, RecordValidationError> {
        guard draft.type != .unknown else { return .failure(.unknownType) }

        var a = Activity(babyId: draft.babyId, type: draft.type)
        a.startTime = draft.startTime
        if let end = draft.endTime { a.endTime = end }
        if let dur = draft.duration { a.duration = dur }

        switch draft.type {
        case .feedingBreast:
            a.side = draft.side ?? .left

        case .feedingBottle:
            guard let ml = Double(draft.amountText), ml > 0, ml <= 500 else {
                return .failure(.invalidAmount(isPumping: false))
            }
            a.amount = ml
            a.feedingContent = draft.feedingContent

        case .feedingPumping:
            guard let ml = Double(draft.amountText), ml > 0, ml <= 500 else {
                return .failure(.invalidAmount(isPumping: true))
            }
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
            guard let t = Double(draft.temperatureText), t >= 34.0, t <= 43.0 else {
                return .failure(.invalidTemperature)
            }
            a.temperature = t

        case .medication:
            a.medicationName = draft.medicationName.isEmpty ? nil : draft.medicationName
            a.medicationDosage = draft.medicationDosage.isEmpty ? nil : draft.medicationDosage

        case .bath:
            break

        case .unknown:
            return .failure(.unknownType)
        }

        // 공통 검증: 최소 1초(수동조정 예외) + 수면 24h 상한
        if let dur = a.duration, dur < 1, !draft.wasManuallyAdjusted {
            return .failure(.tooShort)
        }
        if draft.type == .sleep, let dur = a.duration, dur > AppConstants.secondsPerDay {
            return .failure(.sleepTooLong)
        }

        let trimmed = draft.note.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { a.note = trimmed }

        return .success(a)
    }
}

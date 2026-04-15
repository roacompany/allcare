import Foundation

// MARK: - FoodSafetyService
// 이유식 활동 + 알레르기 기록을 결합하여 식품별 안전 분류 및 히스토리를 제공합니다.
// 참고용 기록 기반 분류이며 의학적 진단이 아닙니다.

enum FoodSafetyService {

    // MARK: - Status Classification

    /// 식품 이름, 관련 활동 목록, 알레르기 기록을 분석하여 FoodSafetyStatus 반환
    /// - forbidden: 알레르기 기록이 있거나, reaction == .allergy 활동이 있는 경우
    /// - caution: reaction == .allergy 없으나 부정적 반응(.refused/.negative 유사)이 있는 경우
    /// - safe: 3회 이상 시도하고 부정적 반응이 없는 경우
    /// - 기본: caution (데이터 부족)
    static func classify(
        foodName: String,
        activities: [Activity],
        allergyRecords: [AllergyRecord]
    ) -> FoodSafetyStatus {
        let normalizedFood = foodName.trimmingCharacters(in: .whitespaces).lowercased()

        // forbidden: 알레르기 기록에 해당 식품이 있으면 금지
        let hasAllergyRecord = allergyRecords.contains { record in
            record.allergenName.lowercased().contains(normalizedFood) ||
            normalizedFood.contains(record.allergenName.lowercased())
        }
        if hasAllergyRecord { return .forbidden }

        // 해당 음식 관련 이유식 활동
        let relatedActivities = activities.filter { activity in
            guard activity.type == .feedingSolid || activity.type == .feedingSnack,
                  let name = activity.foodName else { return false }
            let normalizedName = name.lowercased()
            return normalizedName.contains(normalizedFood) || normalizedFood.contains(normalizedName)
        }

        // forbidden: allergy reaction 활동
        let hasAllergyReaction = relatedActivities.contains { $0.foodReaction == .allergy }
        if hasAllergyReaction { return .forbidden }

        guard !relatedActivities.isEmpty else { return .caution }

        // caution: refused 반응 포함 시
        let hasRefusedReaction = relatedActivities.contains { $0.foodReaction == .refused }
        if hasRefusedReaction { return .caution }

        // safe: 3회 이상 시도, 모두 good/normal
        let positiveTrials = relatedActivities.filter {
            $0.foodReaction == .good || $0.foodReaction == .normal || $0.foodReaction == nil
        }
        if positiveTrials.count >= 3 { return .safe }

        return .caution
    }

    // MARK: - All Food Names

    /// 활동 + 알레르기 기록에서 고유 음식 이름 목록 추출 (정규화)
    static func allFoodNames(activities: [Activity], allergyRecords: [AllergyRecord]) -> [String] {
        var names = Set<String>()

        for activity in activities where activity.type == .feedingSolid || activity.type == .feedingSnack {
            if let foodName = activity.foodName, !foodName.isEmpty {
                // 콤마로 구분된 복합 음식 분리
                let parts = foodName.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                parts.filter { !$0.isEmpty }.forEach { names.insert($0) }
            }
        }

        for record in allergyRecords where !record.allergenName.isEmpty {
            names.insert(record.allergenName)
        }

        return names.sorted()
    }

    // MARK: - FoodSafetyEntry List

    /// 전체 음식 이름에 대한 FoodSafetyEntry 배열 반환
    static func buildEntries(
        activities: [Activity],
        allergyRecords: [AllergyRecord]
    ) -> [FoodSafetyEntry] {
        let names = allFoodNames(activities: activities, allergyRecords: allergyRecords)

        return names.map { name in
            let relatedActivities = activitiesForFood(name: name, activities: activities)
            let status = classify(foodName: name, activities: activities, allergyRecords: allergyRecords)
            let trialCount = relatedActivities.count
            let reactionCount = relatedActivities.filter {
                $0.foodReaction == .allergy || $0.foodReaction == .refused
            }.count
            let dates = relatedActivities.map(\.startTime).sorted()

            return FoodSafetyEntry(
                foodName: name,
                status: status,
                trialCount: trialCount,
                reactionCount: reactionCount,
                firstTriedDate: dates.first,
                lastTriedDate: dates.last
            )
        }
    }

    // MARK: - Food History

    /// 특정 식품의 시도 타임라인을 FoodHistoryEvent 배열로 반환
    static func buildHistory(
        foodName: String,
        activities: [Activity],
        allergyRecords: [AllergyRecord]
    ) -> [FoodHistoryEvent] {
        var events: [FoodHistoryEvent] = []

        let relatedActivities = activitiesForFood(name: foodName, activities: activities)
            .sorted { $0.startTime < $1.startTime }

        var consecutiveGoodCount = 0

        for (index, activity) in relatedActivities.enumerated() {
            let kind: FoodHistoryEventKind
            switch activity.foodReaction {
            case .allergy:
                kind = .reaction
                consecutiveGoodCount = 0
            case .refused:
                kind = .tried
                consecutiveGoodCount = 0
            default:
                consecutiveGoodCount += 1
                // 3회 연속 good/normal → safe 이벤트
                if consecutiveGoodCount == 3 {
                    kind = .safe
                } else {
                    kind = .tried
                }
            }

            _ = index
            let event = FoodHistoryEvent(
                foodName: foodName,
                date: activity.startTime,
                kind: kind,
                note: activity.note
            )
            events.append(event)
        }

        // 알레르기 기록도 포함
        let relatedAllergies = allergyRecords.filter { record in
            let normalizedRecord = record.allergenName.lowercased()
            let normalizedFood = foodName.lowercased()
            return normalizedRecord.contains(normalizedFood) || normalizedFood.contains(normalizedRecord)
        }

        for record in relatedAllergies {
            let event = FoodHistoryEvent(
                foodName: foodName,
                date: record.date,
                kind: .reaction,
                note: record.note
            )
            events.append(event)
        }

        return events.sorted { $0.date < $1.date }
    }

    // MARK: - Auto-Suggest Trigger

    /// 이유식 저장 시 알레르기 자동 제안이 필요한지 판단
    /// reaction == .allergy 또는 .refused 시 true 반환
    static func shouldSuggestAllergyRecord(for activity: Activity) -> Bool {
        guard activity.type == .feedingSolid || activity.type == .feedingSnack else { return false }
        return activity.foodReaction == .allergy || activity.foodReaction == .refused
    }

    // MARK: - Private Helpers

    private static func activitiesForFood(name: String, activities: [Activity]) -> [Activity] {
        let normalizedTarget = name.trimmingCharacters(in: .whitespaces).lowercased()
        return activities.filter { activity in
            guard activity.type == .feedingSolid || activity.type == .feedingSnack,
                  let foodName = activity.foodName, !foodName.isEmpty else { return false }
            let parts = foodName.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            return parts.contains(normalizedTarget)
        }
    }
}

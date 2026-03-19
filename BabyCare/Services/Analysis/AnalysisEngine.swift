import Foundation
import FirebaseFirestore

// MARK: - 분석 엔진 진입점

final class AnalysisEngine: @unchecked Sendable {
    static let shared = AnalysisEngine()
    private init() {}

    private nonisolated(unsafe) let db = Firestore.firestore()

    // MARK: - 메인 분석 실행

    func run(
        baby: Baby,
        visit: HospitalVisit,
        activities: [Activity],
        previousVisitDate: Date?,
        gestationalWeeks: Int = 40,
        userId: String
    ) async -> AnalysisResult {

        // Step 1: 전처리
        let period = Preprocessor.analysisPeriod(
            scheduledDate: visit.scheduledDate ?? visit.visitDate,
            previousVisitDate: previousVisitDate
        )
        let correctedAge = Preprocessor.correctedAgeInDays(
            birthDate: baby.birthDate,
            gestationalWeeks: gestationalWeeks,
            referenceDate: period.to
        )
        let aggregates = Preprocessor.aggregate(activities: activities, period: period)

        guard aggregates.count >= 7 else {
            return AnalysisResult(
                babyId: baby.id,
                hospitalVisitId: visit.id,
                period: period,
                correctedAgeInDays: correctedAge,
                dailyAggregates: aggregates,
                checklistItems: ["분석 기간이 짧아 데이터가 부족합니다. 병원에서 전반적인 상태를 확인해 주세요."]
            )
        }

        // Step 2: Layer 1 — 연령별 참조값 비교
        let layer1Flags = referenceCheck(aggregates: aggregates, ageInDays: correctedAge)

        // Step 3: Layer 2 — 개인 기준선 이탈 감지
        let layer2Flags = BaselineDetector.detect(aggregates: aggregates, ageInDays: correctedAge)

        let allFlags = layer1Flags + layer2Flags

        // Step 4: Layer 3 — 다변량 패턴 분류
        let patterns = PatternClassifier.classify(flags: allFlags, aggregates: aggregates)
        let adjustedFlags = PatternClassifier.suppressGrowthSpurtFlags(allFlags, patterns: patterns)

        // Step 5: Layer 4 — 임상 유의성 필터 + 우선순위
        let clinicalFlags = ClinicalFilter.filter(flags: adjustedFlags, aggregates: aggregates)
        let prioritized = ClinicalFilter.prioritize(flags: clinicalFlags, patterns: patterns)
        let checklist = ClinicalFilter.generateChecklist(
            flags: prioritized,
            patterns: patterns,
            ageInDays: correctedAge
        )

        var result = AnalysisResult(
            babyId: baby.id,
            hospitalVisitId: visit.id,
            period: period,
            correctedAgeInDays: correctedAge,
            dailyAggregates: aggregates,
            flags: allFlags,
            patterns: patterns,
            prioritizedFlags: prioritized,
            checklistItems: checklist,
            disclaimerRequired: true
        )

        // Firestore 캐시 저장
        await saveResult(result, userId: userId)

        return result
    }

    // MARK: - Layer 1: 연령별 참조값 비교

    private func referenceCheck(aggregates: [DailyAggregate], ageInDays: Int) -> [MetricFlag] {
        var flags: [MetricFlag] = []
        let recent = Array(aggregates.suffix(7))

        let avgFeeding = recent.map { Double($0.feedingCount) }.reduce(0, +) / Double(recent.count)
        let avgSleepHrs = recent.map { $0.sleepMinutes / 60.0 }.reduce(0, +) / Double(recent.count)
        let avgDiaper = recent.map { Double($0.diaperCount) }.reduce(0, +) / Double(recent.count)

        let feedRef = ReferenceTable.feedingCount(ageInDays: ageInDays)
        let sleepRef = ReferenceTable.sleepHours(ageInDays: ageInDays)
        let diaperRef = ReferenceTable.diaperCount(ageInDays: ageInDays)

        if !feedRef.contains(avgFeeding) {
            let dev = feedRef.deviation(of: avgFeeding)
            flags.append(MetricFlag(
                metric: .feeding, layer: .reference,
                direction: avgFeeding < feedRef.min ? .down : .up,
                sigmaDistance: dev, score: dev
            ))
        }
        if !sleepRef.contains(avgSleepHrs) {
            let dev = sleepRef.deviation(of: avgSleepHrs)
            flags.append(MetricFlag(
                metric: .sleep, layer: .reference,
                direction: avgSleepHrs < sleepRef.min ? .down : .up,
                sigmaDistance: dev, score: dev
            ))
        }
        if !diaperRef.contains(avgDiaper) {
            let dev = diaperRef.deviation(of: avgDiaper)
            flags.append(MetricFlag(
                metric: .diaper, layer: .reference,
                direction: avgDiaper < diaperRef.min ? .down : .up,
                sigmaDistance: dev, score: dev
            ))
        }

        return flags
    }

    // MARK: - Firestore 캐시

    private func saveResult(_ result: AnalysisResult, userId: String) async {
        let ref = db.collection("users").document(userId)
            .collection("babies").document(result.babyId)
            .collection("hospitalReports").document(result.id)
        try? ref.setData(from: result)
    }

    func fetchCachedResult(babyId: String, visitId: String, userId: String) async -> AnalysisResult? {
        let snapshot = try? await db.collection("users").document(userId)
            .collection("babies").document(babyId)
            .collection("hospitalReports")
            .whereField("hospitalVisitId", isEqualTo: visitId)
            .limit(to: 1)
            .getDocuments()
        return snapshot?.documents.first.flatMap { try? $0.data(as: AnalysisResult.self) }
    }
}

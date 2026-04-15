import Foundation

// MARK: - 소아과 체크리스트 자동 생성 서비스
// 의학적 진단이 아닌 참고용 체크리스트입니다.

enum HospitalChecklistService {

    // MARK: - 증상 키워드 (최근 7일 활동 note 분석용)

    private static let symptomKeywords: [String] = [
        "발열", "열", "고열",
        "기침", "콧물", "재채기",
        "구토", "설사", "변비",
        "발진", "두드러기",
        "보챔", "울음", "불편"
    ]

    // MARK: - Public API

    /// 소아과 체크리스트 생성
    /// - Parameters:
    ///   - vaccinations: 전체 예방접종 목록
    ///   - growthRecords: 성장 기록 목록
    ///   - activities: 활동 기록 목록 (최근 7일 분석용)
    ///   - baby: 아기 정보 (성별·생년월일 기반 백분위 계산)
    /// - Returns: 중요도순 정렬된 체크리스트 항목
    static func generate(
        vaccinations: [Vaccination],
        growthRecords: [GrowthRecord],
        activities: [Activity],
        baby: Baby
    ) -> [HospitalChecklistItem] {
        var items: [HospitalChecklistItem] = []

        items += vaccinationItems(from: vaccinations)
        items += growthAnomalyItems(from: growthRecords, baby: baby)
        items += symptomItems(from: activities)

        // 중요도 높은 순 정렬 후 중복 제거
        return items
            .sorted { $0.severity > $1.severity }
    }

    // MARK: - 예방접종 체크리스트

    /// 다음 예방접종 D-day 기반 체크리스트 생성
    static func vaccinationItems(from vaccinations: [Vaccination]) -> [HospitalChecklistItem] {
        var items: [HospitalChecklistItem] = []

        let pendingVaccinations = vaccinations
            .filter { !$0.isCompleted }
            .sorted { $0.scheduledDate < $1.scheduledDate }

        // 지연된 접종
        let overdue = pendingVaccinations.filter { $0.isOverdue }
        for vax in overdue.prefix(3) {
            let days = Calendar.current.dateComponents([.day], from: vax.scheduledDate, to: Date()).day ?? 0
            items.append(HospitalChecklistItem(
                type: .vaccination,
                title: String(
                    format: NSLocalizedString("hospital.checklist.vaccination.overdue", comment: ""),
                    vax.vaccine.displayName,
                    vax.doseNumber
                ),
                detail: String(
                    format: NSLocalizedString("hospital.checklist.vaccination.overdue.detail", comment: ""),
                    days
                ),
                severity: .high
            ))
        }

        // 가장 가까운 예정 접종 (D-day 계산)
        if let nextVax = pendingVaccinations.first(where: { !$0.isOverdue }),
           let dDay = nextVax.daysUntilScheduled {
            let severity: HospitalChecklistItem.Severity = dDay <= 7 ? .medium : .low
            items.append(HospitalChecklistItem(
                type: .vaccination,
                title: String(
                    format: NSLocalizedString("hospital.checklist.vaccination.upcoming", comment: ""),
                    nextVax.vaccine.displayName,
                    nextVax.doseNumber,
                    dDay
                ),
                detail: DateFormatters.shortDate.string(from: nextVax.scheduledDate),
                severity: severity
            ))
        }

        return items
    }

    // MARK: - 성장 이상 체크리스트

    /// 직전 측정값이 백분위 밴드(3rd~97th) 밖으로 이탈한 경우 체크리스트 생성
    static func growthAnomalyItems(from growthRecords: [GrowthRecord], baby: Baby) -> [HospitalChecklistItem] {
        guard !growthRecords.isEmpty else { return [] }

        var items: [HospitalChecklistItem] = []
        let sorted = growthRecords.sorted { $0.date < $1.date }
        guard let latest = sorted.last else { return [] }

        let ageMonths = Calendar.current.dateComponents(
            [.month], from: baby.birthDate, to: latest.date
        ).month ?? 0
        let clampedAge = max(0, min(24, ageMonths))

        // 체중 체크
        if let weight = latest.weight,
           let percentile = PercentileCalculator.percentile(value: weight, ageMonths: clampedAge, gender: baby.gender, metric: .weight) {
            if percentile < 3 || percentile > 97 {
                items.append(HospitalChecklistItem(
                    type: .growthAnomaly,
                    title: String(
                        format: NSLocalizedString("hospital.checklist.growth.weight.anomaly", comment: ""),
                        Int(percentile)
                    ),
                    detail: String(format: "%.2fkg", weight),
                    severity: .high
                ))
            }
        }

        // 키 체크
        if let height = latest.height,
           let percentile = PercentileCalculator.percentile(value: height, ageMonths: clampedAge, gender: baby.gender, metric: .height) {
            if percentile < 3 || percentile > 97 {
                items.append(HospitalChecklistItem(
                    type: .growthAnomaly,
                    title: String(
                        format: NSLocalizedString("hospital.checklist.growth.height.anomaly", comment: ""),
                        Int(percentile)
                    ),
                    detail: String(format: "%.1fcm", height),
                    severity: .high
                ))
            }
        }

        return items
    }

    // MARK: - 증상 키워드 체크리스트

    /// 최근 7일 활동 note에서 증상 키워드를 추출하여 체크리스트 생성
    static func symptomItems(from activities: [Activity]) -> [HospitalChecklistItem] {
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let recentActivities = activities.filter { $0.startTime >= sevenDaysAgo }

        // 노트 및 투약 기록 수집
        var foundKeywords: Set<String> = []

        for activity in recentActivities {
            // note에서 키워드 탐지
            if let note = activity.note {
                let lowercased = note.lowercased()
                for keyword in symptomKeywords where lowercased.contains(keyword) {
                    foundKeywords.insert(keyword)
                }
            }

            // 체온 38도 이상 감지
            if let temp = activity.temperature, temp >= 38.0 {
                foundKeywords.insert("발열")
            }

            // 투약 기록 감지
            if activity.type == .medication, let medName = activity.medicationName {
                foundKeywords.insert(medName)
            }
        }

        guard !foundKeywords.isEmpty else { return [] }

        let keywordList = foundKeywords.sorted().joined(separator: ", ")
        return [
            HospitalChecklistItem(
                type: .symptomKeyword,
                title: String(
                    format: NSLocalizedString("hospital.checklist.symptom.detected", comment: ""),
                    keywordList
                ),
                detail: NSLocalizedString("hospital.checklist.symptom.detail", comment: ""),
                severity: .medium
            )
        ]
    }
}

import Foundation

// MARK: - MedicationSafetyService
// 소아 투약 안전 용량 검증 서비스
// 참고: AAP(미국소아과학회) / 대한소아과학회 기준
// 이 정보는 참고용이며 반드시 의사/약사와 상담하세요.

enum MedicationSafetyService {

    // MARK: - Medication Database

    struct MedicationInfo {
        let displayName: String          // 표시 이름
        let keywords: [String]           // 매칭 키워드
        let minDosePerKg: Double         // 최소 용량 (mg/kg/회)
        let maxDosePerKg: Double         // 최대 용량 (mg/kg/회)
        let maxDailyDoses: Int           // 1일 최대 투여 횟수
        let minAgeMonths: Int            // 최소 월령 (개월)
        let concentration: Double?       // 일반 시럽 농도 (mg/ml), nil이면 정보 없음
        let unit: String                 // 표시 단위 (mg 또는 ml)
        let notes: String?               // 추가 안내
    }

    static let knownMedications: [MedicationInfo] = [
        MedicationInfo(
            displayName: "아세트아미노펜 (타이레놀)",
            keywords: ["타이레놀", "아세트아미노펜", "acetaminophen", "paracetamol", "어린이타이레놀"],
            minDosePerKg: 10,
            maxDosePerKg: 15,
            maxDailyDoses: 4,
            minAgeMonths: 3,
            concentration: 32,          // 어린이 시럽 32mg/ml
            unit: "mg",
            notes: "4~6시간 간격, 1일 최대 4회"
        ),
        MedicationInfo(
            displayName: "이부프로펜",
            keywords: ["이부프로펜", "ibuprofen", "맥시부펜", "부루펜", "어린이부루펜"],
            minDosePerKg: 5,
            maxDosePerKg: 10,
            maxDailyDoses: 3,
            minAgeMonths: 6,
            concentration: 20,          // 시럽 20mg/ml
            unit: "mg",
            notes: "6~8시간 간격, 1일 최대 3회. 생후 6개월 이상"
        ),
        MedicationInfo(
            displayName: "해열좌약 (아세트아미노펜)",
            keywords: ["해열좌약", "좌약", "좌제", "씨알좌약"],
            minDosePerKg: 10,
            maxDosePerKg: 15,
            maxDailyDoses: 4,
            minAgeMonths: 3,
            concentration: nil,
            unit: "mg",
            notes: "4~6시간 간격. 좌약 규격(80mg/125mg/150mg/300mg) 중 체중에 맞는 것 선택"
        ),
        MedicationInfo(
            displayName: "덱시부프로펜",
            keywords: ["덱시부프로펜", "dexibuprofen", "맥시덱스"],
            minDosePerKg: 5,
            maxDosePerKg: 7.5,
            maxDailyDoses: 3,
            minAgeMonths: 6,
            concentration: 15,          // 시럽 15mg/ml
            unit: "mg",
            notes: "6~8시간 간격, 1일 최대 3회. 생후 6개월 이상"
        )
    ]

    // MARK: - Lookup

    static func medication(for name: String) -> MedicationInfo? {
        let lower = name.lowercased()
        return knownMedications.first { info in
            info.keywords.contains { lower.contains($0.lowercased()) }
        }
    }

    // MARK: - Safety Validation Result

    enum ValidationResult {
        case ageRestriction(minMonths: Int)          // 너무 어림
        case safeDoseInfo(minMg: Double, maxMg: Double, weightKg: Double, minMl: Double?, maxMl: Double?)
        case doseExceeded(enteredMg: Double, maxMg: Double)
        case unknown                                  // 알 수 없는 약
    }

    // MARK: - Validate

    /// 이름 기반 안전 용량 정보 반환 (용량 비교 없이 정보만)
    static func safetyInfo(
        medicationName: String,
        weightKg: Double?,
        ageMonths: Int
    ) -> ValidationResult? {
        guard !medicationName.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        guard let info = medication(for: medicationName) else { return .unknown }

        if ageMonths < info.minAgeMonths {
            return .ageRestriction(minMonths: info.minAgeMonths)
        }

        guard let weight = weightKg, weight > 0 else {
            return .safeDoseInfo(minMg: 0, maxMg: 0, weightKg: 0, minMl: nil, maxMl: nil)
        }

        let minMg = info.minDosePerKg * weight
        let maxMg = info.maxDosePerKg * weight

        var minMl: Double?
        var maxMl: Double?
        if let conc = info.concentration, conc > 0 {
            minMl = minMg / conc
            maxMl = maxMg / conc
        }

        return .safeDoseInfo(minMg: minMg, maxMg: maxMg, weightKg: weight, minMl: minMl, maxMl: maxMl)
    }

    /// 입력된 용량(ml 문자열)이 안전 범위를 초과하는지 검증
    static func validateDosage(
        medicationName: String,
        dosageString: String,
        weightKg: Double?,
        ageMonths: Int
    ) -> ValidationResult? {
        guard !medicationName.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        guard let info = medication(for: medicationName) else { return nil }
        guard let weight = weightKg, weight > 0 else { return nil }

        if ageMonths < info.minAgeMonths {
            return .ageRestriction(minMonths: info.minAgeMonths)
        }

        // 입력 용량 파싱 — ml 또는 mg 지원
        let cleaned = dosageString.lowercased()
            .replacingOccurrences(of: "ml", with: "")
            .replacingOccurrences(of: "mg", with: "")
            .replacingOccurrences(of: " ", with: "")
        guard let enteredValue = Double(cleaned), enteredValue > 0 else { return nil }

        // ml 입력이면 mg으로 변환
        var enteredMg = enteredValue
        if dosageString.lowercased().contains("ml"), let conc = info.concentration {
            enteredMg = enteredValue * conc
        }

        let maxMg = info.maxDosePerKg * weight
        if enteredMg > maxMg {
            return .doseExceeded(enteredMg: enteredMg, maxMg: maxMg)
        }

        return nil
    }

    // MARK: - Age Helper

    static func ageInMonths(from birthDate: Date) -> Int {
        let components = Calendar.current.dateComponents([.month], from: birthDate, to: Date())
        return max(0, components.month ?? 0)
    }
}

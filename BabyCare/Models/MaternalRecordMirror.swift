import Foundation

/// 산모수첩 미러 최신 수치 1개(칩 1개에 대응).
struct MaternalMeasurement: Identifiable, Hashable {
    let id: String       // "bp" / "glucose" / "weight"
    let label: String
    let value: String
    let unit: String
    let measuredAt: Date
    let context: String? // 혈당 맥락("공복") 등, 없으면 nil
}

/// 산모수첩 디지털 미러 — 기존 검진 수치(혈압/혈당/자궁저높이/EFW=pregnancyVitals, 체중=pregnancyWeights)에서
/// 항목별 최신값을 모아 보여주기 위한 순수 파생. ⚠️ 참고용·의학 단정 아님(safety.md).
enum MaternalRecordMirror {

    /// 항목별 가장 최근 측정값(없는 항목은 제외).
    static func latestMeasurements(vitals: [PregnancyVitalEntry],
                                   weights: [PregnancyWeightEntry]) -> [MaternalMeasurement] {
        var result: [MaternalMeasurement] = []

        // 혈압: 수축기·이완기 둘 다 기록된 가장 최근
        let bpEntries = vitals.filter { $0.systolic != nil && $0.diastolic != nil }
        if let bp = bpEntries.max(by: { $0.measuredAt < $1.measuredAt }),
           let systolic = bp.systolic, let diastolic = bp.diastolic {
            let value = "\(systolic)/\(diastolic)"
            result.append(MaternalMeasurement(id: "bp", label: "혈압", value: value,
                                              unit: "mmHg", measuredAt: bp.measuredAt, context: nil))
        }

        // 혈당: glucose 기록된 가장 최근(측정 맥락 라벨 동반)
        let glucoseEntries = vitals.filter { $0.glucose != nil }
        if let entry = glucoseEntries.max(by: { $0.measuredAt < $1.measuredAt }),
           let glucose = entry.glucose {
            let ctx = entry.glucoseContext.flatMap { PregnancyVitalEntry.GlucoseContext(rawValue: $0)?.displayName }
            result.append(MaternalMeasurement(id: "glucose", label: "혈당", value: "\(glucose)",
                                              unit: "mg/dL", measuredAt: entry.measuredAt, context: ctx))
        }

        // 체중: 가장 최근
        if let weightEntry = weights.max(by: { $0.measuredAt < $1.measuredAt }) {
            let value = String(format: "%.1f", weightEntry.weight)
            result.append(MaternalMeasurement(id: "weight", label: "체중", value: value,
                                              unit: weightEntry.unit, measuredAt: weightEntry.measuredAt, context: nil))
        }

        // 자궁저높이(cm): 가장 최근
        if let entry = vitals.filter({ $0.fundalHeight != nil }).max(by: { $0.measuredAt < $1.measuredAt }),
           let fundal = entry.fundalHeight {
            result.append(MaternalMeasurement(id: "fundalHeight", label: "자궁저높이",
                                              value: String(format: "%.1f", fundal),
                                              unit: "cm", measuredAt: entry.measuredAt, context: nil))
        }

        // 태아 추정 체중(EFW, g): 가장 최근
        if let entry = vitals.filter({ $0.estimatedFetalWeight != nil }).max(by: { $0.measuredAt < $1.measuredAt }),
           let efw = entry.estimatedFetalWeight {
            result.append(MaternalMeasurement(id: "efw", label: "태아 추정 체중",
                                              value: String(format: "%.0f", efw),
                                              unit: "g", measuredAt: entry.measuredAt, context: nil))
        }

        return result
    }
}

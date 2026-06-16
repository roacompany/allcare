import Foundation

/// 혈압/혈당 측정 1행 (신규 컬렉션 pregnancyVitals). 혈압·혈당 중 하나 이상 기록.
struct PregnancyVitalEntry: Identifiable, Codable, Hashable {
    var id: String
    var pregnancyId: String
    var systolic: Int?       // 수축기 mmHg
    var diastolic: Int?      // 이완기 mmHg
    var glucose: Int?        // 혈당 mg/dL
    /// 혈당 측정 맥락 (fasting|postMeal1h|postMeal2h). 문자열 저장 — rawValue 영구 계약 회피.
    var glucoseContext: String?
    var measuredAt: Date
    var notes: String?
    var createdAt: Date

    init(id: String = UUID().uuidString, pregnancyId: String,
         systolic: Int? = nil, diastolic: Int? = nil,
         glucose: Int? = nil, glucoseContext: String? = nil,
         measuredAt: Date = Date(), notes: String? = nil, createdAt: Date = Date()) {
        self.id = id
        self.pregnancyId = pregnancyId
        self.systolic = systolic
        self.diastolic = diastolic
        self.glucose = glucose
        self.glucoseContext = glucoseContext
        self.measuredAt = measuredAt
        self.notes = notes
        self.createdAt = createdAt
    }

    /// 혈당 측정 맥락.
    enum GlucoseContext: String, CaseIterable, Identifiable {
        case fasting, postMeal1h, postMeal2h
        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .fasting: return "공복"
            case .postMeal1h: return "식후 1시간"
            case .postMeal2h: return "식후 2시간"
            }
        }
        /// 한국 임신성 당뇨 참고 목표선(mg/dL) — 진단 아님, 참고선 표시·비교용.
        var referenceCeiling: Int {
            switch self {
            case .fasting: return 95
            case .postMeal1h: return 140
            case .postMeal2h: return 120
            }
        }
    }

    /// 혈당이 참고 목표선 이하인지(차트 RuleMark 비교용, 의학 단정 아님).
    static func glucoseWithinReference(value: Int, context: GlucoseContext) -> Bool {
        value <= context.referenceCeiling
    }
}

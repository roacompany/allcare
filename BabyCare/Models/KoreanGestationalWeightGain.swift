import Foundation

/// 임신 전 BMI에 따른 권장 체중 증가 밴드 (대한산부인과학회 기준).
///
/// ⚠️ 의학적 판단 텍스트("정상/위험/부족") 금지 — 참고 밴드와 위치(밴드 내/아래/위)만 제공한다.
/// ⚠️ **총 증가 범위는 FEATURES.md §③ LOCK** (대한산부인과학회). 주차별 누적 밴드(1삼분기 오프셋·
///    구간 선형 보간)는 **의료감수 전 초안** — 만삭(40주) 끝점만 LOCK 총량에 정박하고 중간은 보간이다.
/// ⚠️ 다태아(쌍둥이+)는 단태아 밴드를 그대로 적용하지 않는다 — 호출부(fetusCount>1)에서 밴드 비노출.
enum KoreanGestationalWeightGain {

    /// 임신 전 BMI = 체중(kg) / 키(m)². 키·체중이 양수가 아니면 nil.
    static func bmi(heightCm: Double, weightKg: Double) -> Double? {
        guard heightCm > 0, weightKg > 0 else { return nil }
        let meters = heightCm / 100.0
        return weightKg / (meters * meters)
    }

    /// 임신 전 BMI 분류 (한국 기준 — 비만 컷오프 ≥25, 서구 ≥30과 다름).
    enum Category: String, CaseIterable, Equatable {
        case underweight, normal, overweight, obese

        /// 한국 BMI 컷오프: 저체중<18.5 / 정상 18.5~22.9 / 과체중 23~24.9 / 비만 ≥25.
        static func category(forBMI bmi: Double) -> Category {
            switch bmi {
            case ..<18.5: return .underweight
            case ..<23.0: return .normal
            case ..<25.0: return .overweight
            default:      return .obese
            }
        }

        var displayName: String {
            switch self {
            case .underweight: return "저체중"
            case .normal:      return "정상"
            case .overweight:  return "과체중"
            case .obese:       return "비만"
            }
        }

        /// 권장 총 증가 범위(kg, 만삭). **FEATURES.md §③ LOCK (대한산부인과학회).**
        /// 비만은 "7kg 미만" → 하한 없음(0).
        var recommendedTotalGainKg: ClosedRange<Double> {
            switch self {
            case .underweight: return 12.5...18.0
            case .normal:      return 11.5...15.0
            case .overweight:  return 7.0...11.5
            case .obese:       return 0.0...7.0
            }
        }

        /// 1삼분기(≈13주) 말 누적 권장 증가(kg) — **의료감수 전 초안**.
        /// 초기엔 적게 늘거나 입덧으로 정체/감소도 정상 범위.
        var firstTrimesterGainKg: ClosedRange<Double> {
            switch self {
            case .underweight, .normal: return 0.5...2.0
            case .overweight, .obese:   return 0.0...1.0
            }
        }
    }

    /// 주차별 권장 누적 증가 밴드(kg). 구간 선형 보간: (0주, 0) → (13주, 1삼분기) → (40주, 총량).
    /// week<0이면 nil, week>40이면 40주로 클램프(만삭 후 동일).
    static func recommendedCumulativeRange(atWeek week: Int, category: Category) -> ClosedRange<Double>? {
        guard week >= 0 else { return nil }
        let w = min(Double(week), 40.0)
        let firstTri = category.firstTrimesterGainKg
        let total = category.recommendedTotalGainKg
        let lower = interpolate(week: w, at13: firstTri.lowerBound, at40: total.lowerBound)
        let upper = interpolate(week: w, at13: firstTri.upperBound, at40: total.upperBound)
        return lower...upper
    }

    /// (0,0)→(13,at13)→(40,at40) 2구간 선형 보간. w는 0...40로 가정.
    private static func interpolate(week w: Double, at13: Double, at40: Double) -> Double {
        if w <= 13.0 {
            return at13 * (w / 13.0)
        } else {
            return at13 + (at40 - at13) * ((w - 13.0) / (40.0 - 13.0))
        }
    }

    /// 현재 누적 증가량이 권장 밴드의 어디에 있는지. **경고 톤 없음 — 위치만.**
    enum BandPosition: Equatable {
        case below, within, above
    }

    /// 누적 증가량(gain)의 밴드 내 위치. 밴드를 구할 수 없으면 nil. 경계값은 within.
    static func position(cumulativeGainKg gain: Double, atWeek week: Int, category: Category) -> BandPosition? {
        guard let range = recommendedCumulativeRange(atWeek: week, category: category) else { return nil }
        if gain < range.lowerBound { return .below }
        if gain > range.upperBound { return .above }
        return .within
    }

    /// 밴드 표시에 필요한 조립 결과. 표시 가능할 때만 생성된다.
    struct Guidance: Equatable {
        let category: Category
        let week: Int
        let cumulativeGainKg: Double
        let band: ClosedRange<Double>
        let position: BandPosition
    }

    /// 임신 전 키·체중 + 현재 체중·주차로 밴드 표시 상태를 조립한다.
    /// nil이면 밴드 비노출: 다태아(단태아 밴드 비적용)·임신 전 키/체중 미입력·현재 체중/주차 없음.
    static func guidance(
        prePregnancyHeightCm: Double?,
        prePregnancyWeightKg: Double?,
        latestWeightKg: Double?,
        currentWeek: Int?,
        fetusCount: Int?
    ) -> Guidance? {
        // 다태아는 단태아 밴드를 적용하지 않는다.
        guard (fetusCount ?? 1) == 1 else { return nil }
        guard let heightCm = prePregnancyHeightCm,
              let baseWeight = prePregnancyWeightKg,
              let latest = latestWeightKg,
              let week = currentWeek,
              let bmiValue = bmi(heightCm: heightCm, weightKg: baseWeight) else { return nil }
        let category = Category.category(forBMI: bmiValue)
        guard let band = recommendedCumulativeRange(atWeek: week, category: category),
              let pos = position(cumulativeGainKg: latest - baseWeight, atWeek: week, category: category) else { return nil }
        return Guidance(
            category: category,
            week: week,
            cumulativeGainKg: latest - baseWeight,
            band: band,
            position: pos
        )
    }
}

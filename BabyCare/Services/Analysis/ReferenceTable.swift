import Foundation

// MARK: - 연령별 정상 참조값 (Layer 1)
// 출처: AAP 2022, AASM 2016, WHO 2006

struct ReferenceRange {
    var min: Double
    var max: Double

    func contains(_ value: Double) -> Bool { value >= min && value <= max }
    func deviation(of value: Double) -> Double {
        if value < min { return min - value }
        if value > max { return value - max }
        return 0
    }
}

enum ReferenceTable {

    // MARK: - 수유 횟수 (회/일) — AAP 2022
    static func feedingCount(ageInDays: Int) -> ReferenceRange {
        switch ageInDays {
        case 0...30:    return ReferenceRange(min: 8, max: 12)
        case 31...90:   return ReferenceRange(min: 7, max: 10)
        case 91...180:  return ReferenceRange(min: 6, max: 8)
        case 181...365: return ReferenceRange(min: 5, max: 6)   // 6-12개월
        default:        return ReferenceRange(min: 4, max: 6)   // 12-24개월 (3식 + 간식)
        }
    }

    // MARK: - 수유량 회당 (ml) — AAP / Medela 메타분석
    static func feedingAmountMl(ageInDays: Int) -> ReferenceRange {
        switch ageInDays {
        case 0...30:    return ReferenceRange(min: 30, max: 90)
        case 31...180:  return ReferenceRange(min: 60, max: 120)
        case 181...365: return ReferenceRange(min: 150, max: 240)  // 6-12개월
        default:        return ReferenceRange(min: 180, max: 300)  // 12-24개월
        }
    }

    // MARK: - 수면 시간 (시간/일)
    // ⚠️ 0-90일: AASM 공식 권장값 미제정 — 임상 관찰 기반 참고값
    // 91-365일: AASM 2016 (12-16h, 낮잠 포함)
    // 366-730일: AASM 2016 (11-14h)
    static func sleepHours(ageInDays: Int) -> ReferenceRange {
        switch ageInDays {
        case 0...90:  return ReferenceRange(min: 14, max: 17)  // 임상 관찰 기반
        case 91...365: return ReferenceRange(min: 12, max: 16) // AASM 2016
        default:      return ReferenceRange(min: 11, max: 14)  // AASM 2016 (12-24개월)
        }
    }

    // MARK: - 기저귀 횟수 (회/일) — AAP / Pampers
    static func diaperCount(ageInDays: Int) -> ReferenceRange {
        switch ageInDays {
        case 0...30:    return ReferenceRange(min: 8, max: 12)
        case 31...90:   return ReferenceRange(min: 7, max: 10)
        case 91...365:  return ReferenceRange(min: 4, max: 6)   // 91-365일
        default:        return ReferenceRange(min: 3, max: 5)   // 12-24개월
        }
    }

    // MARK: - 정상 체온 (°C)
    static let normalTemperature = ReferenceRange(min: 36.5, max: 37.5)
    static let feverThreshold: Double = 38.0

    // MARK: - WHO LMS Z-score 계산
    // Z = [(X/M)^L - 1] / (L × S)
    // 출처: WHO Child Growth Standards 2006
    static func lmsZScore(value: Double, L: Double, M: Double, S: Double) -> Double {
        guard L != 0, M > 0, S > 0 else { return 0 }
        return (pow(value / M, L) - 1.0) / (L * S)
    }
}

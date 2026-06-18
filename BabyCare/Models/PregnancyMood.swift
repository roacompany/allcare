import Foundation

/// 임신 중 가벼운 정서(기분) 체크인 기록.
///
/// ⚠️ 의료적 우울 스크리닝/진단 아님 — 가벼운 기분 기록 + 선택 메모에 머문다.
///    위험도 판정·점수화 금지(safety.md 의학 단정 금지). 빈도/추이만 모아 보여준다.
/// ⚠️ 정서 데이터는 Analytics/Crashlytics에 포함 금지(민감 건강정보).
/// pregnancies/{pid}/pregnancyMoods/{id}.
struct PregnancyMood: Identifiable, Codable, Hashable {
    var id: String
    var pregnancyId: String
    var mood: Mood
    /// 자유 메모 (선택).
    var memo: String?
    var occurredAt: Date
    var createdAt: Date

    /// 기분 5단계 (이모지 체크인). rawValue = Firestore 영구 저장값 — 변경 금지.
    enum Mood: String, Codable, CaseIterable, Identifiable {
        case great, good, okay, low, hard

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .great: return "아주 좋아요"
            case .good:  return "좋아요"
            case .okay:  return "그저 그래요"
            case .low:   return "조금 힘들어요"
            case .hard:  return "많이 힘들어요"
            }
        }

        var emoji: String {
            switch self {
            case .great: return "😊"
            case .good:  return "🙂"
            case .okay:  return "😐"
            case .low:   return "😟"
            case .hard:  return "😢"
            }
        }
    }

    init(
        id: String = UUID().uuidString,
        pregnancyId: String,
        mood: Mood,
        memo: String? = nil,
        occurredAt: Date = Date(),
        createdAt: Date = Date()
    ) {
        self.id = id
        self.pregnancyId = pregnancyId
        self.mood = mood
        self.memo = memo
        self.occurredAt = occurredAt
        self.createdAt = createdAt
    }
}

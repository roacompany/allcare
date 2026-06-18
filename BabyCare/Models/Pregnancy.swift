import Foundation

/// 임신 데이터 모델. Baby와 독립된 루트 엔티티 (users/{uid}/pregnancies/{pid}).
/// 출산 시 일부 필드가 Baby로 prefill되며 archivedAt 설정.
struct Pregnancy: Identifiable, Codable, Hashable {
    var id: String
    /// LMP(마지막 생리 시작일) — 주차 계산의 1차 기준.
    var lmpDate: Date?
    /// 출산 예정일 (LMP + 280일 또는 초음파 보정).
    var dueDate: Date?
    /// 예정일 변경 이력. 덮어쓰기 금지, append-only.
    var eddHistory: [Date]?
    /// 태아 수 (기본 1). 쌍둥이/삼둥이 지원. nil일 경우 1로 해석.
    var fetusCount: Int?
    /// 태명 (출산 시 Baby.name prefill 후보).
    var babyNickname: String?
    /// 초음파로 확인된 성별. 출산 시 Baby.gender prefill 후보.
    var ultrasoundGender: Baby.Gender?
    /// 출산 전환 상태 머신: pending|completed. WriteBatch 중간 실패 복구용.
    var transitionState: String?
    /// 임신 종료 상태. nil이면 ongoing으로 해석.
    var outcome: PregnancyOutcome?
    /// 종료 일시. outcome != ongoing일 때 설정.
    var archivedAt: Date?
    /// 임신 전 체중 (체중 증가 기준선).
    var prePregnancyWeight: Double?
    /// 임신 전 키(cm) — BMI 권장 증가밴드 기준점. nil이면 밴드 미표시.
    var prePregnancyHeight: Double?
    /// 체중 단위 (kg|lb).
    var weightUnit: String?
    /// 파트너 공유 UID 목록 (read-only).
    var sharedWith: [String]?
    var createdAt: Date
    var updatedAt: Date

    /// 소유자 UID. Firestore에 영속화 — 공유 임신 소유자 식별 (비대칭 공유 owner-write 기준).
    /// optional이므로 레거시 문서(필드 없음)는 nil로 안전 디코딩. 없으면 path-based fallback 사용.
    var ownerUserId: String?

    /// 국민행복카드 수동 입력 누적 사용액(원). nil = 미입력. 카드사 미연동 — 사용자 직접 기록.
    /// (#41: @AppStorage 기기전역 금지 → Pregnancy 문서에 영속해 계정/공유 격리.)
    var voucherUsedAmount: Int?

    enum CodingKeys: String, CodingKey {
        case id, lmpDate, dueDate, eddHistory, fetusCount, babyNickname
        case ultrasoundGender, transitionState, outcome, archivedAt
        case prePregnancyWeight, prePregnancyHeight, weightUnit, sharedWith, createdAt, updatedAt
        case ownerUserId   // 영속화: 공유 임신 소유자 식별 (비대칭 공유 owner-write 기준)
        case voucherUsedAmount
    }

    init(
        id: String = UUID().uuidString,
        lmpDate: Date? = nil,
        dueDate: Date? = nil,
        eddHistory: [Date]? = nil,
        fetusCount: Int? = 1,
        babyNickname: String? = nil,
        ultrasoundGender: Baby.Gender? = nil,
        transitionState: String? = nil,
        outcome: PregnancyOutcome? = .ongoing,
        archivedAt: Date? = nil,
        prePregnancyWeight: Double? = nil,
        prePregnancyHeight: Double? = nil,
        weightUnit: String? = "kg",
        sharedWith: [String]? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.lmpDate = lmpDate
        self.dueDate = dueDate
        self.eddHistory = eddHistory
        self.fetusCount = fetusCount
        self.babyNickname = babyNickname
        self.ultrasoundGender = ultrasoundGender
        self.transitionState = transitionState
        self.outcome = outcome
        self.archivedAt = archivedAt
        self.prePregnancyWeight = prePregnancyWeight
        self.prePregnancyHeight = prePregnancyHeight
        self.weightUnit = weightUnit
        self.sharedWith = sharedWith
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// 현재 임신 주차 (weeks, days) — LMP 기준, Calendar 기반. LMP 없으면 nil.
    /// DST/타임존 안전: Calendar.current.dateComponents 사용.
    var currentWeekAndDay: (weeks: Int, days: Int)? {
        guard let lmp = lmpDate else { return nil }
        let comps = Calendar.current.dateComponents([.day], from: lmp, to: Date())
        guard let totalDays = comps.day, totalDays >= 0 else { return nil }
        return (weeks: totalDays / 7, days: totalDays % 7)
    }

    /// 아카이브 표시용 "최종 주차" — 종료/출산 시각(archivedAt) 기준, 없으면 오늘.
    /// (currentWeekAndDay는 Date() 기준이라 종료된 임신에서 계속 증가하는 버그 회피.)
    var finalWeekAndDay: (weeks: Int, days: Int)? {
        PregnancyDateMath.weekAndDay(from: lmpDate, now: archivedAt ?? Date())
    }

    /// 예정일까지 남은 일수 (음수 가능). dueDate 없으면 nil.
    var dDay: Int? {
        guard let due = dueDate else { return nil }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let dueDay = cal.startOfDay(for: due)
        return cal.dateComponents([.day], from: today, to: dueDay).day
    }

    /// 출산 전환 시트 성별 prefill. ultrasoundGender(Baby.Gender) 직접 사용, 없으면 .male.
    /// (구버전 버그: rawValue↔displayName 비교로 항상 .male로 떨어짐 — 직접 대입으로 수정.)
    var genderPrefill: Baby.Gender {
        ultrasoundGender ?? .male
    }

    /// 단태아 여부.
    var isSingleton: Bool {
        (fetusCount ?? 1) == 1
    }
}

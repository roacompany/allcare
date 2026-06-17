import Foundation

/// 산전 진찰 방문 기록.
struct PrenatalVisit: Identifiable, Codable, Hashable {
    var id: String
    var pregnancyId: String
    var scheduledAt: Date
    var visitedAt: Date?
    var hospitalName: String?
    var doctorName: String?
    var visitType: String?  // routine|ultrasound|bloodTest|gtt|other — 자유 문자열 (영구 계약 회피)
    var notes: String?
    var isCompleted: Bool
    var reminderEnabled: Bool?
    /// 진료 때 물어볼 질문 메모(임베딩·optional 신규 필드). nil = 구버전 문서 호환.
    var preparationQuestions: [VisitPrepQuestion]?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        pregnancyId: String,
        scheduledAt: Date,
        visitedAt: Date? = nil,
        hospitalName: String? = nil,
        doctorName: String? = nil,
        visitType: String? = nil,
        notes: String? = nil,
        isCompleted: Bool = false,
        reminderEnabled: Bool? = true,
        preparationQuestions: [VisitPrepQuestion]? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.pregnancyId = pregnancyId
        self.scheduledAt = scheduledAt
        self.visitedAt = visitedAt
        self.hospitalName = hospitalName
        self.doctorName = doctorName
        self.visitType = visitType
        self.notes = notes
        self.isCompleted = isCompleted
        self.reminderEnabled = reminderEnabled
        self.preparationQuestions = preparationQuestions
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// 아직 "물어봤어요" 표시되지 않은 질문 수(히어로 배지용).
    var openQuestionCount: Int {
        preparationQuestions?.filter { !$0.asked }.count ?? 0
    }

    /// 예정일까지 남은 일수 (음수 가능).
    var daysUntilScheduled: Int {
        let cal = Calendar.current
        return cal.dateComponents([.day], from: cal.startOfDay(for: Date()),
                                   to: cal.startOfDay(for: scheduledAt)).day ?? 0
    }

    /// 14일 이내 예정.
    var isDueSoon: Bool {
        !isCompleted && daysUntilScheduled >= 0 && daysUntilScheduled <= 14
    }

    /// 초과 (예정일 지났으나 미완료).
    var isOverdue: Bool {
        !isCompleted && daysUntilScheduled < 0
    }
}

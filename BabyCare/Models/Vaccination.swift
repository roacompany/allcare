import Foundation

struct Vaccination: Identifiable, Codable, Hashable {
    var id: String
    var babyId: String
    var vaccine: VaccineType
    var doseNumber: Int
    var scheduledDate: Date
    var administeredDate: Date?
    var isCompleted: Bool
    var hospital: String?
    var doctor: String?
    var batchNumber: String?
    var sideEffects: String?
    var note: String?
    var createdAt: Date

    /// 한국 국가예방접종 기준
    enum VaccineType: String, Codable, CaseIterable {
        case bcg = "BCG"
        case hepB = "B형간염"
        case dtap = "DTaP"
        case ipv = "IPV"
        case hib = "Hib"
        case pcv = "PCV"
        case rotavirus = "로타바이러스"
        case mmr = "MMR"
        case varicella = "수두"
        case hepA = "A형간염"
        case japaneseEncephalitis = "일본뇌염"
        case influenza = "인플루엔자"
        case other = "기타"

        var displayName: String { rawValue }

        var icon: String {
            "syringe.fill"
        }
    }

    var isOverdue: Bool {
        !isCompleted && scheduledDate < Date()
    }

    var isDueSoon: Bool {
        guard !isCompleted else { return false }
        let daysUntil = Calendar.current.dateComponents([.day], from: Date(), to: scheduledDate).day ?? 0
        return daysUntil >= 0 && daysUntil <= 14
    }

    var statusText: String {
        if isCompleted { return "접종 완료" }
        if isOverdue { return "접종 지연" }
        if isDueSoon { return "접종 예정" }
        return "예정"
    }

    init(
        id: String = UUID().uuidString,
        babyId: String,
        vaccine: VaccineType,
        doseNumber: Int = 1,
        scheduledDate: Date,
        administeredDate: Date? = nil,
        isCompleted: Bool = false,
        hospital: String? = nil,
        doctor: String? = nil,
        batchNumber: String? = nil,
        sideEffects: String? = nil,
        note: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.babyId = babyId
        self.vaccine = vaccine
        self.doseNumber = doseNumber
        self.scheduledDate = scheduledDate
        self.administeredDate = administeredDate
        self.isCompleted = isCompleted
        self.hospital = hospital
        self.doctor = doctor
        self.batchNumber = batchNumber
        self.sideEffects = sideEffects
        self.note = note
        self.createdAt = createdAt
    }

    /// 한국 국가예방접종 스케줄 생성 (생년월일 기준)
    static func generateSchedule(babyId: String, birthDate: Date) -> [Vaccination] {
        let cal = Calendar.current
        func date(months: Int) -> Date {
            cal.date(byAdding: .month, value: months, to: birthDate) ?? birthDate
        }
        func date(years: Int) -> Date {
            cal.date(byAdding: .year, value: years, to: birthDate) ?? birthDate
        }

        return [
            // 출생 시
            Vaccination(babyId: babyId, vaccine: .bcg, doseNumber: 1, scheduledDate: birthDate),
            Vaccination(babyId: babyId, vaccine: .hepB, doseNumber: 1, scheduledDate: birthDate),
            // 1개월
            Vaccination(babyId: babyId, vaccine: .hepB, doseNumber: 2, scheduledDate: date(months: 1)),
            // 2개월
            Vaccination(babyId: babyId, vaccine: .dtap, doseNumber: 1, scheduledDate: date(months: 2)),
            Vaccination(babyId: babyId, vaccine: .ipv, doseNumber: 1, scheduledDate: date(months: 2)),
            Vaccination(babyId: babyId, vaccine: .hib, doseNumber: 1, scheduledDate: date(months: 2)),
            Vaccination(babyId: babyId, vaccine: .pcv, doseNumber: 1, scheduledDate: date(months: 2)),
            Vaccination(babyId: babyId, vaccine: .rotavirus, doseNumber: 1, scheduledDate: date(months: 2)),
            // 4개월
            Vaccination(babyId: babyId, vaccine: .dtap, doseNumber: 2, scheduledDate: date(months: 4)),
            Vaccination(babyId: babyId, vaccine: .ipv, doseNumber: 2, scheduledDate: date(months: 4)),
            Vaccination(babyId: babyId, vaccine: .hib, doseNumber: 2, scheduledDate: date(months: 4)),
            Vaccination(babyId: babyId, vaccine: .pcv, doseNumber: 2, scheduledDate: date(months: 4)),
            Vaccination(babyId: babyId, vaccine: .rotavirus, doseNumber: 2, scheduledDate: date(months: 4), note: "로타릭스(Rotarix) 2회 완료 — 4개월 2차로 기본 접종 종료"),
            // 6개월
            Vaccination(babyId: babyId, vaccine: .dtap, doseNumber: 3, scheduledDate: date(months: 6)),
            Vaccination(babyId: babyId, vaccine: .ipv, doseNumber: 3, scheduledDate: date(months: 6)),
            Vaccination(babyId: babyId, vaccine: .hib, doseNumber: 3, scheduledDate: date(months: 6)),
            Vaccination(babyId: babyId, vaccine: .pcv, doseNumber: 3, scheduledDate: date(months: 6)),
            Vaccination(babyId: babyId, vaccine: .hepB, doseNumber: 3, scheduledDate: date(months: 6)),
            Vaccination(babyId: babyId, vaccine: .influenza, doseNumber: 1, scheduledDate: date(months: 6), note: "초회 접종 시 4주 간격으로 2회 접종 필요"),
            Vaccination(babyId: babyId, vaccine: .influenza, doseNumber: 2, scheduledDate: date(months: 7), note: "초회 접종 시에만 해당 (이전 접종 이력 없는 경우)"),
            // 12~15개월
            Vaccination(babyId: babyId, vaccine: .hib, doseNumber: 4, scheduledDate: date(months: 12)),
            Vaccination(babyId: babyId, vaccine: .pcv, doseNumber: 4, scheduledDate: date(months: 12)),
            Vaccination(babyId: babyId, vaccine: .mmr, doseNumber: 1, scheduledDate: date(months: 12)),
            Vaccination(babyId: babyId, vaccine: .varicella, doseNumber: 1, scheduledDate: date(months: 12)),
            Vaccination(babyId: babyId, vaccine: .hepA, doseNumber: 1, scheduledDate: date(months: 12)),
            Vaccination(babyId: babyId, vaccine: .japaneseEncephalitis, doseNumber: 1, scheduledDate: date(months: 12)),
            // 15~18개월
            Vaccination(babyId: babyId, vaccine: .dtap, doseNumber: 4, scheduledDate: date(months: 15)),
            // 24개월
            Vaccination(babyId: babyId, vaccine: .hepA, doseNumber: 2, scheduledDate: date(months: 24)),
            Vaccination(babyId: babyId, vaccine: .japaneseEncephalitis, doseNumber: 2, scheduledDate: date(months: 24)),
            // 36개월
            Vaccination(babyId: babyId, vaccine: .japaneseEncephalitis, doseNumber: 3, scheduledDate: date(months: 36)),
            // 4~6세
            Vaccination(babyId: babyId, vaccine: .dtap, doseNumber: 5, scheduledDate: date(years: 4)),
            Vaccination(babyId: babyId, vaccine: .ipv, doseNumber: 4, scheduledDate: date(years: 4)),
            Vaccination(babyId: babyId, vaccine: .mmr, doseNumber: 2, scheduledDate: date(years: 4)),
            Vaccination(babyId: babyId, vaccine: .varicella, doseNumber: 2, scheduledDate: date(years: 4)),
        ]
    }
}

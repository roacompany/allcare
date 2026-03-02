import Foundation

struct Milestone: Identifiable, Codable, Hashable {
    var id: String
    var babyId: String
    var category: MilestoneCategory
    var title: String
    var description: String?
    var expectedAgeMonths: Int?
    var achievedDate: Date?
    var isAchieved: Bool
    var photoURL: String?
    var note: String?
    var createdAt: Date

    enum MilestoneCategory: String, Codable, CaseIterable {
        case motor = "motor"
        case cognitive = "cognitive"
        case language = "language"
        case social = "social"
        case selfCare = "self_care"

        var displayName: String {
            switch self {
            case .motor: "대근육/소근육"
            case .cognitive: "인지"
            case .language: "언어"
            case .social: "사회성"
            case .selfCare: "자조"
            }
        }

        var icon: String {
            switch self {
            case .motor: "figure.walk"
            case .cognitive: "brain.head.profile"
            case .language: "bubble.left.fill"
            case .social: "person.2.fill"
            case .selfCare: "hand.raised.fill"
            }
        }
    }

    var achievedAgeText: String? {
        guard let date = achievedDate else { return nil }
        // 달성 시 아기 나이는 외부에서 birthDate와 비교해야 함
        return DateFormatters.shortDate.string(from: date)
    }

    init(
        id: String = UUID().uuidString,
        babyId: String,
        category: MilestoneCategory,
        title: String,
        description: String? = nil,
        expectedAgeMonths: Int? = nil,
        achievedDate: Date? = nil,
        isAchieved: Bool = false,
        photoURL: String? = nil,
        note: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.babyId = babyId
        self.category = category
        self.title = title
        self.description = description
        self.expectedAgeMonths = expectedAgeMonths
        self.achievedDate = achievedDate
        self.isAchieved = isAchieved
        self.photoURL = photoURL
        self.note = note
        self.createdAt = createdAt
    }

    /// 한국 영유아 발달 체크리스트 생성
    static func generateChecklist(babyId: String) -> [Milestone] {
        [
            // 대근육 (Motor)
            Milestone(babyId: babyId, category: .motor, title: "고개 들기", expectedAgeMonths: 1),
            Milestone(babyId: babyId, category: .motor, title: "뒤집기", expectedAgeMonths: 4),
            Milestone(babyId: babyId, category: .motor, title: "혼자 앉기", expectedAgeMonths: 6),
            Milestone(babyId: babyId, category: .motor, title: "기어가기", expectedAgeMonths: 8),
            Milestone(babyId: babyId, category: .motor, title: "잡고 서기", expectedAgeMonths: 9),
            Milestone(babyId: babyId, category: .motor, title: "혼자 걷기", expectedAgeMonths: 12),
            Milestone(babyId: babyId, category: .motor, title: "계단 오르기", expectedAgeMonths: 18),
            Milestone(babyId: babyId, category: .motor, title: "뛰기", expectedAgeMonths: 24),

            // 소근육 (Motor fine)
            Milestone(babyId: babyId, category: .motor, title: "물건 쥐기", expectedAgeMonths: 3),
            Milestone(babyId: babyId, category: .motor, title: "장난감 옮기기", expectedAgeMonths: 6),
            Milestone(babyId: babyId, category: .motor, title: "엄지-검지 집기", expectedAgeMonths: 9),
            Milestone(babyId: babyId, category: .motor, title: "숟가락 사용", expectedAgeMonths: 15),
            Milestone(babyId: babyId, category: .motor, title: "낙서하기", expectedAgeMonths: 18),

            // 인지 (Cognitive)
            Milestone(babyId: babyId, category: .cognitive, title: "소리에 반응", expectedAgeMonths: 1),
            Milestone(babyId: babyId, category: .cognitive, title: "얼굴 주시", expectedAgeMonths: 2),
            Milestone(babyId: babyId, category: .cognitive, title: "물건 따라보기", expectedAgeMonths: 3),
            Milestone(babyId: babyId, category: .cognitive, title: "까꿍 놀이 반응", expectedAgeMonths: 6),
            Milestone(babyId: babyId, category: .cognitive, title: "숨긴 물건 찾기", expectedAgeMonths: 9),
            Milestone(babyId: babyId, category: .cognitive, title: "간단한 지시 이해", expectedAgeMonths: 12),
            Milestone(babyId: babyId, category: .cognitive, title: "도형 맞추기", expectedAgeMonths: 18),

            // 언어 (Language)
            Milestone(babyId: babyId, category: .language, title: "옹알이", expectedAgeMonths: 3),
            Milestone(babyId: babyId, category: .language, title: "자음+모음 소리", expectedAgeMonths: 6),
            Milestone(babyId: babyId, category: .language, title: "엄마/아빠 (의미)", expectedAgeMonths: 10),
            Milestone(babyId: babyId, category: .language, title: "단어 3~5개", expectedAgeMonths: 12),
            Milestone(babyId: babyId, category: .language, title: "두 단어 조합", expectedAgeMonths: 20),
            Milestone(babyId: babyId, category: .language, title: "문장으로 말하기", expectedAgeMonths: 30),

            // 사회성 (Social)
            Milestone(babyId: babyId, category: .social, title: "사회적 미소", expectedAgeMonths: 2),
            Milestone(babyId: babyId, category: .social, title: "낯가림", expectedAgeMonths: 7),
            Milestone(babyId: babyId, category: .social, title: "바이바이", expectedAgeMonths: 9),
            Milestone(babyId: babyId, category: .social, title: "또래 관심", expectedAgeMonths: 15),
            Milestone(babyId: babyId, category: .social, title: "역할 놀이", expectedAgeMonths: 24),

            // 자조 (Self-care)
            Milestone(babyId: babyId, category: .selfCare, title: "컵으로 마시기", expectedAgeMonths: 12),
            Milestone(babyId: babyId, category: .selfCare, title: "혼자 먹기 시도", expectedAgeMonths: 15),
            Milestone(babyId: babyId, category: .selfCare, title: "신발 벗기", expectedAgeMonths: 18),
            Milestone(babyId: babyId, category: .selfCare, title: "배변 훈련 시작", expectedAgeMonths: 24),
        ]
    }
}

import Foundation

struct Milestone: Identifiable, Codable, Hashable {
    var id: String
    var babyId: String
    var category: MilestoneCategory
    var title: String
    var description: String?
    var expectedAgeMonths: Int?
    var expectedAgeRangeEnd: Int?
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
        expectedAgeRangeEnd: Int? = nil,
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
        self.expectedAgeRangeEnd = expectedAgeRangeEnd
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
            Milestone(babyId: babyId, category: .motor, title: "고개 들기", description: "엎드린 자세에서 머리를 들어올려요", expectedAgeMonths: 1, expectedAgeRangeEnd: 2),
            Milestone(babyId: babyId, category: .motor, title: "뒤집기", description: "등에서 배로, 또는 배에서 등으로 뒤집어요", expectedAgeMonths: 4, expectedAgeRangeEnd: 6),
            Milestone(babyId: babyId, category: .motor, title: "혼자 앉기", description: "도움 없이 잠시 동안 앉아 있을 수 있어요", expectedAgeMonths: 5, expectedAgeRangeEnd: 8),
            Milestone(babyId: babyId, category: .motor, title: "기어가기", description: "배밀이 또는 네발 기기로 이동해요", expectedAgeMonths: 6, expectedAgeRangeEnd: 10),
            Milestone(babyId: babyId, category: .motor, title: "잡고 서기", description: "가구 등을 잡고 일어서요", expectedAgeMonths: 9, expectedAgeRangeEnd: 12),
            Milestone(babyId: babyId, category: .motor, title: "혼자 걷기", description: "잡지 않고 몇 걸음 걸어요", expectedAgeMonths: 9, expectedAgeRangeEnd: 18),
            Milestone(babyId: babyId, category: .motor, title: "계단 오르기", description: "난간이나 손을 잡고 계단을 올라요", expectedAgeMonths: 16, expectedAgeRangeEnd: 20),
            Milestone(babyId: babyId, category: .motor, title: "뛰기", description: "두 발로 뛰어올라요", expectedAgeMonths: 22, expectedAgeRangeEnd: 26),

            // 소근육 (Motor fine)
            Milestone(babyId: babyId, category: .motor, title: "물건 쥐기", description: "손에 닿는 물건을 쥐어요", expectedAgeMonths: 3, expectedAgeRangeEnd: 5),
            Milestone(babyId: babyId, category: .motor, title: "장난감 옮기기", description: "한 손에서 다른 손으로 옮겨요", expectedAgeMonths: 6, expectedAgeRangeEnd: 8),
            Milestone(babyId: babyId, category: .motor, title: "엄지-검지 집기", description: "작은 물건을 엄지와 검지로 집어요", expectedAgeMonths: 8, expectedAgeRangeEnd: 11),
            Milestone(babyId: babyId, category: .motor, title: "숟가락 사용", description: "숟가락으로 음식을 떠서 입으로 가져가요", expectedAgeMonths: 14, expectedAgeRangeEnd: 18),
            Milestone(babyId: babyId, category: .motor, title: "낙서하기", description: "크레용이나 연필로 선을 그어요", expectedAgeMonths: 15, expectedAgeRangeEnd: 20),

            // 인지 (Cognitive)
            Milestone(babyId: babyId, category: .cognitive, title: "소리에 반응", description: "큰 소리에 놀라거나 소리 방향으로 고개를 돌려요", expectedAgeMonths: 1, expectedAgeRangeEnd: 2),
            Milestone(babyId: babyId, category: .cognitive, title: "얼굴 주시", description: "가까이 있는 얼굴을 뚫어지게 봐요", expectedAgeMonths: 1, expectedAgeRangeEnd: 3),
            Milestone(babyId: babyId, category: .cognitive, title: "물건 따라보기", description: "움직이는 물건을 눈으로 따라가요", expectedAgeMonths: 2, expectedAgeRangeEnd: 4),
            Milestone(babyId: babyId, category: .cognitive, title: "까꿍 놀이 반응", description: "까꿍 놀이에 웃거나 기대해요", expectedAgeMonths: 5, expectedAgeRangeEnd: 8),
            Milestone(babyId: babyId, category: .cognitive, title: "숨긴 물건 찾기", description: "천으로 덮인 장난감을 찾아요 (대상 영속성)", expectedAgeMonths: 8, expectedAgeRangeEnd: 10),
            Milestone(babyId: babyId, category: .cognitive, title: "간단한 지시 이해", description: "'주세요', '안 돼' 같은 말을 이해해요", expectedAgeMonths: 10, expectedAgeRangeEnd: 14),
            Milestone(babyId: babyId, category: .cognitive, title: "도형 맞추기", description: "간단한 모양 맞추기 퍼즐을 해요", expectedAgeMonths: 16, expectedAgeRangeEnd: 22),

            // 언어 (Language)
            Milestone(babyId: babyId, category: .language, title: "옹알이", description: "'아', '우' 같은 모음 소리를 내요", expectedAgeMonths: 2, expectedAgeRangeEnd: 4),
            Milestone(babyId: babyId, category: .language, title: "자음+모음 소리", description: "'바바', '마마' 같은 소리를 반복해요", expectedAgeMonths: 5, expectedAgeRangeEnd: 8),
            Milestone(babyId: babyId, category: .language, title: "엄마/아빠 (의미)", description: "특정 사람을 가리키며 '엄마', '아빠' 말해요", expectedAgeMonths: 9, expectedAgeRangeEnd: 12),
            Milestone(babyId: babyId, category: .language, title: "첫 단어", description: "의미 있는 단어를 사용해요", expectedAgeMonths: 10, expectedAgeRangeEnd: 14),
            Milestone(babyId: babyId, category: .language, title: "단어 3~5개", description: "의미 있는 단어를 3~5개 사용해요", expectedAgeMonths: 12, expectedAgeRangeEnd: 16),
            Milestone(babyId: babyId, category: .language, title: "두 단어 조합", description: "'맘마 줘', '아빠 가' 같은 조합을 해요", expectedAgeMonths: 18, expectedAgeRangeEnd: 24),
            Milestone(babyId: babyId, category: .language, title: "문장으로 말하기", description: "3~4단어 문장으로 의사소통해요", expectedAgeMonths: 24, expectedAgeRangeEnd: 36),

            // 사회성 (Social)
            Milestone(babyId: babyId, category: .social, title: "사회적 미소", description: "사람 얼굴을 보고 의도적으로 웃어요", expectedAgeMonths: 2, expectedAgeRangeEnd: 3),
            Milestone(babyId: babyId, category: .social, title: "낯가림", description: "낯선 사람에게 불안해하거나 울어요", expectedAgeMonths: 6, expectedAgeRangeEnd: 9),
            Milestone(babyId: babyId, category: .social, title: "바이바이", description: "손을 흔들어 인사해요", expectedAgeMonths: 9, expectedAgeRangeEnd: 12),
            Milestone(babyId: babyId, category: .social, title: "또래 관심", description: "다른 아이들에게 관심을 보여요", expectedAgeMonths: 12, expectedAgeRangeEnd: 18),
            Milestone(babyId: babyId, category: .social, title: "역할 놀이", description: "인형 먹이기, 전화 놀이 등 상상 놀이를 해요", expectedAgeMonths: 18, expectedAgeRangeEnd: 30),

            // 자조 (Self-care)
            Milestone(babyId: babyId, category: .selfCare, title: "컵으로 마시기", description: "양손으로 컵을 잡고 마셔요", expectedAgeMonths: 10, expectedAgeRangeEnd: 14),
            Milestone(babyId: babyId, category: .selfCare, title: "혼자 먹기 시도", description: "숟가락이나 손으로 직접 먹으려고 해요", expectedAgeMonths: 12, expectedAgeRangeEnd: 18),
            Milestone(babyId: babyId, category: .selfCare, title: "신발 벗기", description: "스스로 신발을 벗을 수 있어요", expectedAgeMonths: 16, expectedAgeRangeEnd: 22),
            Milestone(babyId: babyId, category: .selfCare, title: "배변 훈련 시작", description: "변기에 앉아보거나 기저귀 불편함을 표현해요", expectedAgeMonths: 18, expectedAgeRangeEnd: 30),
        ]
    }
}

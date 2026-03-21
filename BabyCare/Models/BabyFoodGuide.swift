import Foundation

// MARK: - BabyFoodStage

enum BabyFoodStage: Int, CaseIterable, Identifiable {
    case early = 0       // 초기 (4~5개월)
    case earlyMid = 1    // 초기~중기 (6~7개월)
    case mid = 2         // 중기 (8~9개월)
    case late = 3        // 후기 (10~12개월)
    case toddler = 4     // 유아식 (13~24개월)

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .early:    "초기 이유식"
        case .earlyMid: "초기~중기 이유식"
        case .mid:      "중기 이유식"
        case .late:     "후기 이유식"
        case .toddler:  "유아식"
        }
    }

    var subtitle: String {
        switch self {
        case .early:    "미음 단계"
        case .earlyMid: "죽 단계"
        case .mid:      "다진 단계"
        case .late:     "무른밥 단계"
        case .toddler:  "일반 식사 단계"
        }
    }

    var monthRange: ClosedRange<Int> {
        switch self {
        case .early:    4...5
        case .earlyMid: 6...7
        case .mid:      8...9
        case .late:     10...12
        case .toddler:  13...24
        }
    }

    var monthRangeText: String {
        switch self {
        case .early:    "4~5개월"
        case .earlyMid: "6~7개월"
        case .mid:      "8~9개월"
        case .late:     "10~12개월"
        case .toddler:  "13~24개월"
        }
    }

    var colorHex: String {
        switch self {
        case .early:    "F4A261"  // 따뜻한 주황
        case .earlyMid: "5CB8E4"  // 하늘색
        case .mid:      "85C1A3"  // 세이지 그린
        case .late:     "7B9FE8"  // 인디고
        case .toddler:  "A078D4"  // 소프트 퍼플
        }
    }

    var icon: String {
        switch self {
        case .early:    "drop.fill"
        case .earlyMid: "leaf.fill"
        case .mid:      "fork.knife"
        case .late:     "bowl.fill"
        case .toddler:  "star.fill"
        }
    }

    /// 아기의 현재 월령이 이 단계에 해당하는지 확인
    func contains(ageInMonths: Int) -> Bool {
        monthRange.contains(ageInMonths)
    }
}

// MARK: - BabyFoodRecipe

struct BabyFoodRecipe: Identifiable {
    let id: String
    let stage: BabyFoodStage
    let title: String
    let description: String
    let ingredients: [String]
    let steps: [String]
    let allergyWarnings: [String]
}

// MARK: - BabyFoodGuideData

enum BabyFoodGuideData {
    static let disclaimerText = "이유식 시작 시기는 아기마다 다릅니다. 소아과 전문의와 상담 후 시작하세요. WHO는 생후 6개월까지 완전 모유수유를 권장합니다."

    static let allRecipes: [BabyFoodRecipe] = early + earlyMid + mid + late + toddler

    static func recipes(for stage: BabyFoodStage) -> [BabyFoodRecipe] {
        allRecipes.filter { $0.stage == stage }
    }

    // MARK: 초기 (4~5개월) — 미음

    static let early: [BabyFoodRecipe] = [
        BabyFoodRecipe(
            id: "early-1",
            stage: .early,
            title: "쌀미음",
            description: "아기 첫 이유식의 기본. 묽게 끓인 쌀미음으로 소화 적응을 시작해요.",
            ingredients: ["쌀 10g", "물 200ml"],
            steps: [
                "쌀을 30분 이상 불려둡니다.",
                "불린 쌀을 믹서기에 곱게 갑니다.",
                "냄비에 쌀가루와 물을 넣고 약불에서 10~15분 저어가며 끓입니다.",
                "식혀서 체에 한 번 걸러 매끄럽게 만들어 줍니다."
            ],
            allergyWarnings: []
        ),
        BabyFoodRecipe(
            id: "early-2",
            stage: .early,
            title: "감자미음",
            description: "부드러운 감자로 만든 미음. 포만감을 주고 소화가 잘 돼요.",
            ingredients: ["감자 20g", "쌀 5g", "물 180ml"],
            steps: [
                "감자는 껍질을 벗겨 잘게 썰고, 쌀은 30분 불립니다.",
                "감자와 쌀을 함께 냄비에 넣고 물을 부어 푹 끓입니다.",
                "믹서기로 곱게 갈아줍니다.",
                "체에 걸러 매끄럽게 만든 후 식혀서 제공합니다."
            ],
            allergyWarnings: []
        ),
        BabyFoodRecipe(
            id: "early-3",
            stage: .early,
            title: "고구마미음",
            description: "달콤한 고구마로 만든 미음. 비타민A와 식이섬유가 풍부해요.",
            ingredients: ["고구마 20g", "쌀 5g", "물 180ml"],
            steps: [
                "고구마는 껍질을 벗겨 잘게 썹니다.",
                "쌀은 30분 불려둡니다.",
                "냄비에 고구마, 쌀, 물을 넣고 약불에서 15분 끓입니다.",
                "믹서기로 곱게 갈고 체에 걸러 식혀서 제공합니다."
            ],
            allergyWarnings: []
        )
    ]

    // MARK: 초기~중기 (6~7개월) — 죽

    static let earlyMid: [BabyFoodRecipe] = [
        BabyFoodRecipe(
            id: "earlymid-1",
            stage: .earlyMid,
            title: "브로콜리죽",
            description: "영양 만점 브로콜리로 만든 죽. 철분과 비타민이 풍부해요.",
            ingredients: ["브로콜리 15g", "쌀 15g", "물 150ml"],
            steps: [
                "브로콜리를 송이만 떼어 끓는 물에 살짝 데칩니다.",
                "쌀은 30분 불려 곱게 갑니다.",
                "데친 브로콜리를 믹서기로 곱게 갑니다.",
                "냄비에 쌀, 브로콜리, 물을 넣고 약불에서 15분 저어가며 끓입니다."
            ],
            allergyWarnings: []
        ),
        BabyFoodRecipe(
            id: "earlymid-2",
            stage: .earlyMid,
            title: "당근죽",
            description: "달콤한 당근죽으로 비타민A를 보충해요.",
            ingredients: ["당근 15g", "쌀 15g", "물 150ml"],
            steps: [
                "당근을 잘게 썰어 부드럽게 쪄줍니다.",
                "쌀은 30분 불려둡니다.",
                "찐 당근을 믹서기로 곱게 갑니다.",
                "냄비에 쌀, 당근, 물을 넣고 약불에서 15분 끓입니다."
            ],
            allergyWarnings: []
        ),
        BabyFoodRecipe(
            id: "earlymid-3",
            stage: .earlyMid,
            title: "사과죽",
            description: "새콤달콤 사과죽. 천연 단맛과 식이섬유가 풍부해요.",
            ingredients: ["사과 20g", "쌀 15g", "물 150ml"],
            steps: [
                "사과는 껍질과 씨를 제거하고 잘게 썹니다.",
                "쌀은 30분 불려둡니다.",
                "냄비에 사과와 물을 넣고 사과가 부드러워질 때까지 끓입니다.",
                "사과를 건져 믹서기로 갈고, 쌀과 함께 다시 끓입니다."
            ],
            allergyWarnings: []
        ),
        BabyFoodRecipe(
            id: "earlymid-4",
            stage: .earlyMid,
            title: "소고기죽",
            description: "철분이 풍부한 소고기죽. 6개월부터 철분 보충이 중요해요.",
            ingredients: ["소고기(안심) 20g", "쌀 15g", "물 150ml", "무 5g"],
            steps: [
                "소고기는 핏물을 빼고 잘게 다집니다.",
                "무와 함께 끓는 물에 소고기를 삶아줍니다.",
                "쌀은 30분 불려 곱게 갑니다.",
                "냄비에 쌀, 다진 소고기, 육수를 넣고 약불에서 20분 끓입니다."
            ],
            allergyWarnings: ["소고기"]
        )
    ]

    // MARK: 중기 (8~9개월) — 다진

    static let mid: [BabyFoodRecipe] = [
        BabyFoodRecipe(
            id: "mid-1",
            stage: .mid,
            title: "닭가슴살야채죽",
            description: "단백질 풍부한 닭가슴살과 다양한 야채로 영양을 균형 있게 채워요.",
            ingredients: ["닭가슴살 20g", "쌀 20g", "당근 10g", "애호박 10g", "물 150ml"],
            steps: [
                "닭가슴살을 삶아 곱게 다집니다.",
                "당근, 애호박을 아주 잘게 다집니다.",
                "쌀은 30분 불려둡니다.",
                "냄비에 모든 재료와 물을 넣고 약불에서 20분 끓입니다."
            ],
            allergyWarnings: ["닭고기"]
        ),
        BabyFoodRecipe(
            id: "mid-2",
            stage: .mid,
            title: "두부달걀죽",
            description: "두부와 달걀의 단백질 조합. 부드럽고 소화가 잘 돼요.",
            ingredients: ["두부 30g", "달걀 1/2개", "쌀 20g", "물 150ml"],
            steps: [
                "두부는 으깨거나 아주 잘게 다집니다.",
                "쌀은 30분 불려 반쯤 갑니다.",
                "냄비에 쌀과 물을 넣고 8분 끓인 후 두부를 넣습니다.",
                "달걀 노른자를 풀어 넣고 3분 더 저어가며 끓입니다."
            ],
            allergyWarnings: ["달걀", "대두"]
        ),
        BabyFoodRecipe(
            id: "mid-3",
            stage: .mid,
            title: "연두부바나나",
            description: "간단하고 빠른 간식용 레시피. 조리 없이 바로 줄 수 있어요.",
            ingredients: ["연두부 50g", "바나나 20g"],
            steps: [
                "바나나를 곱게 으깹니다.",
                "연두부를 체에 내려 부드럽게 만듭니다.",
                "으깬 바나나와 연두부를 잘 섞어줍니다.",
                "바로 먹거나 냉장 보관 후 30분 이내 제공합니다."
            ],
            allergyWarnings: ["대두"]
        )
    ]

    // MARK: 후기 (10~12개월) — 무른밥

    static let late: [BabyFoodRecipe] = [
        BabyFoodRecipe(
            id: "late-1",
            stage: .late,
            title: "채소무른밥",
            description: "다양한 채소를 넣은 무른밥. 씹는 연습을 시작해요.",
            ingredients: ["쌀 30g", "당근 10g", "양파 10g", "시금치 5g", "물 120ml"],
            steps: [
                "쌀은 30분 불려둡니다.",
                "당근, 양파를 잘게 다지고, 시금치는 데쳐서 다집니다.",
                "냄비에 쌀, 야채, 물을 넣고 약불에서 20분 끓입니다.",
                "뚜껑을 열고 5분 더 저어가며 수분을 날립니다."
            ],
            allergyWarnings: []
        ),
        BabyFoodRecipe(
            id: "late-2",
            stage: .late,
            title: "생선무른밥",
            description: "DHA가 풍부한 흰살 생선으로 만든 무른밥.",
            ingredients: ["흰살생선(대구/명태) 25g", "쌀 30g", "애호박 10g", "물 120ml"],
            steps: [
                "생선은 가시를 완전히 제거하고 삶아 잘게 찢습니다.",
                "쌀은 30분 불려둡니다.",
                "애호박을 잘게 다집니다.",
                "냄비에 모든 재료와 물을 넣고 약불에서 20분 끓입니다."
            ],
            allergyWarnings: ["생선류"]
        ),
        BabyFoodRecipe(
            id: "late-3",
            stage: .late,
            title: "미역국밥",
            description: "칼슘과 요오드가 풍부한 미역을 넣은 영양 만점 국밥.",
            ingredients: ["건미역 3g", "소고기 20g", "쌀 30g", "참기름 소량", "물 200ml"],
            steps: [
                "건미역을 물에 불려 잘게 자릅니다.",
                "소고기는 잘게 다져 참기름에 살짝 볶습니다.",
                "냄비에 물과 소고기를 넣고 끓이다가 불린 쌀을 넣습니다.",
                "15분 후 미역을 넣고 5분 더 끓입니다."
            ],
            allergyWarnings: ["소고기"]
        )
    ]

    // MARK: 유아식 (13~24개월)

    static let toddler: [BabyFoodRecipe] = [
        BabyFoodRecipe(
            id: "toddler-1",
            stage: .toddler,
            title: "아기비빔밥",
            description: "염분 없이 만든 아기용 비빔밥. 다양한 맛을 경험해요.",
            ingredients: ["밥 100g", "시금치 20g", "당근 15g", "달걀 1개", "참기름 소량"],
            steps: [
                "시금치를 데쳐 잘게 썹니다.",
                "당근을 채 썰어 살짝 볶습니다.",
                "달걀을 스크램블 에그로 만듭니다.",
                "밥 위에 재료를 얹고 참기름을 살짝 두른 후 잘 비벼줍니다."
            ],
            allergyWarnings: ["달걀"]
        ),
        BabyFoodRecipe(
            id: "toddler-2",
            stage: .toddler,
            title: "계란찜",
            description: "부드럽고 포슬포슬한 계란찜. 단백질 보충에 좋아요.",
            ingredients: ["달걀 2개", "물 100ml", "참기름 소량"],
            steps: [
                "달걀을 잘 풀어줍니다.",
                "풀어진 달걀에 물을 2:1 비율로 넣고 섞습니다.",
                "체에 한 번 걸러 매끄럽게 만듭니다.",
                "뚜껑을 덮고 약불에서 10분, 뚜껑을 열고 5분 더 찝니다."
            ],
            allergyWarnings: ["달걀"]
        ),
        BabyFoodRecipe(
            id: "toddler-3",
            stage: .toddler,
            title: "야채전",
            description: "다양한 채소가 들어간 아기용 전. 손으로 집어 먹는 연습이 돼요.",
            ingredients: ["애호박 30g", "당근 20g", "달걀 1개", "밀가루 30g", "식용유 소량"],
            steps: [
                "애호박, 당근을 잘게 채 썹니다.",
                "밀가루, 달걀, 물을 섞어 반죽을 만듭니다.",
                "반죽에 채소를 넣어 골고루 섞습니다.",
                "식용유를 살짝 두른 팬에 반죽을 올려 앞뒤로 노릇하게 구워줍니다."
            ],
            allergyWarnings: ["달걀", "밀(글루텐)"]
        ),
        BabyFoodRecipe(
            id: "toddler-4",
            stage: .toddler,
            title: "치즈리조또",
            description: "부드러운 치즈 향의 아기 리조또. 칼슘 보충에 좋아요.",
            ingredients: ["밥 80g", "체다치즈 1장", "당근 15g", "양파 15g", "육수 100ml"],
            steps: [
                "당근, 양파를 아주 잘게 다져 식용유에 볶습니다.",
                "육수와 밥을 넣고 중약불에서 5분 저어가며 끓입니다.",
                "밥알이 부드러워지면 치즈를 넣고 녹입니다.",
                "고루 섞은 후 적당히 식혀 제공합니다."
            ],
            allergyWarnings: ["유제품"]
        )
    ]
}

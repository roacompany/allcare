import Foundation

/// 규칙의 근거 — 화면에 출처와 확인일을 같이 보여 준다(확인 안 된 건 안내하지 않는다).
struct TripRuleSource: Hashable, Sendable {
    let title: String
    let url: URL
    /// 마지막으로 원문을 연 날 — "yyyy.MM.dd".
    let checkedOn: String
    /// 원문을 직접 못 열었을 때 어떻게 확인했는지 등.
    let note: String?
}

/// 규칙 키 — 할 일 id 의 앞부분이라 바꾸면 저장된 완료 체크가 풀린다(영구 계약).
enum TripRuleKey: String, Hashable, Sendable, CaseIterable {
    case bassinet
    case infantMeal = "infant_meal"
    case solidsQuarantine = "solids_quarantine"
    case liquidsOnboard = "liquids_onboard"
    case carSeat = "car_seat"
    case hotelCrib = "hotel_crib"
}

/// 규칙 카드 한 장 — 문구는 출처 원문에서 옮긴 것만.
struct TripRuleCard: Hashable, Sendable {
    let key: TripRuleKey
    let title: String
    let summary: String
    let exception: String?
    let penalty: String?
    let sources: [TripRuleSource]
}

/// 규칙 카탈로그 v1 — 설계서 §5. 숫자를 바꾸려면 출처를 다시 열고 checkedOn 을 같이 고친다.
enum TripRuleCatalog {
    static let koreanAir = "KE"
    static let bassinetMaxHeightCm: Double = 75
    static let bassinetMaxWeightKg: Double = 11
    static let bassinetDeadlineHours = 48
    static let infantMealDeadlineHours = 24

    private static func url(_ s: String) -> URL {
        guard let u = URL(string: s) else { preconditionFailure("규칙 출처 주소가 잘못됐다: \(s)") }
        return u
    }

    private static let koreanAirSource = TripRuleSource(
        title: "대한항공: 유아 동반 승객",
        url: url("https://www.koreanair.com/us/ko/airport/assistance/travel-with-child"),
        checkedOn: "2026.11.04",
        note: "공식 사이트 직접 접속이 막혀 검색 요약으로 확인")

    static func card(_ key: TripRuleKey) -> TripRuleCard {
        switch key {
        case .bassinet:
            return TripRuleCard(
                key: key, title: "배시넷(기내 요람) 신청",
                summary: "대한항공 국제선은 출발 48시간 전까지 신청해요. 체중 11kg 이하, 키 75cm 이하 아기만 쓸 수 있어요.",
                exception: nil, penalty: nil, sources: [koreanAirSource])
        case .infantMeal:
            return TripRuleCard(
                key: key, title: "유아식 신청",
                summary: "대한항공은 출발 24시간 전까지 유아식(이유식·유아용 주스)을 신청해요.",
                exception: nil, penalty: nil, sources: [koreanAirSource])
        case .solidsQuarantine:
            return TripRuleCard(
                key: key, title: "고기 든 이유식은 일본 반입 제한",
                summary: "고기가 든 식품은 수출국 정부의 검사증명서가 없으면 일본에 가져갈 수 없어요.",
                exception: "일본 지정외 기준에 맞는 공장 제품만(예: 밀봉 뒤 속까지 고온·고압 살균한 것, 액체가 든 밀봉 용기로 뜯지 않고 상온 12개월 이상 보관되는 것). 지퍼·집게로 여닫는 봉지는 밀봉 용기가 아님, 요구하면 서류 제시",
                penalty: "300만 엔 이하 벌금 또는 3년 이하 구금형",
                sources: [
                    TripRuleSource(title: "일본 동물검역소: 육류 제품 반입",
                                   url: url("https://www.maff.go.jp/aqs/tetuzuki/product/aq2.html"),
                                   checkedOn: "2026.11.04", note: nil),
                    TripRuleSource(title: "일본 동물검역소: 지정외 기준",
                                   url: url("https://www.maff.go.jp/aqs/tetuzuki/product/shiteigai.html"),
                                   checkedOn: "2026.11.04", note: nil)
                ])
        case .liquidsOnboard:
            return TripRuleCard(
                key: key, title: "유아식·분유 기내 반입",
                summary: "유아식·분유는 100ml를 넘어도 비행에 필요한 양만큼 가져갈 수 있어요. 보안검색 때 검색요원에게 따로 보여 줘요.",
                exception: nil, penalty: nil,
                sources: [TripRuleSource(title: "국토교통부: 항공기 내 액체류 반입 Q&A",
                                         url: url("https://www.molit.go.kr/USR/policyTarget/dtl.jsp?idx=580"),
                                         checkedOn: "2026.11.04", note: "검색 요약으로 확인")])
        case .carSeat:
            return TripRuleCard(
                key: key, title: "일본 렌터카 카시트",
                summary: "일본은 6세 미만 아이에게 카시트를 써야 해요(택시·버스에 탈 때는 면제). 렌터카 카시트는 미리 요청해요.",
                exception: nil, penalty: nil,
                sources: [
                    TripRuleSource(title: "JAF: 카시트 사용 기간",
                                   url: url("https://jaf.or.jp/common/kuruma-qa/category-accident/subcategory-rule/faq051"),
                                   checkedOn: "2026.11.04", note: nil),
                    TripRuleSource(title: "e-Gov 법령: 도로교통법 시행령 26조의3의2",
                                   url: url("https://laws.e-gov.go.jp/api/1/articles;lawId=335CO0000000270;article=26_3_2"),
                                   checkedOn: "2026.11.04", note: nil)
                ])
        case .hotelCrib:
            // 규칙이 아니라 챙기면 좋은 일 — 출처를 지어내지 않는다.
            return TripRuleCard(
                key: key, title: "숙소에 아기침대 요청",
                summary: "숙소마다 아기침대, 전자레인지·전기포트를 따로 요청하고 확인해요.",
                exception: nil, penalty: nil, sources: [])
        }
    }
}

import Foundation

/// 임신 중 음식·약물 안전 빠른 조회 — 한국 임산부 맥락(순수 정적 데이터·테스트 대상).
///
/// ⚠️ **의료감수 전 초안**(`.dev/specs/pregnancy-mode-v3/context/prenatal-data.md` 후속 H-item).
/// "안전/위험" 의학적 단정이 아니라 일반적으로 통용되는 *주의 수준* 안내이며, 약·한약·개인 위험요인은
/// 반드시 담당 의료진과 상의해야 한다(면책 배너 동반). safety.md: 의학 단정 텍스트 금지 준수.
enum PregnancyFoodSafety {

    /// 일반적 주의 수준(단정 아님 · 참고용).
    enum Level: Hashable {
        case generallyOk   // 대체로 괜찮아요
        case moderate      // 양·빈도에 주의가 필요해요
        case avoid         // 피하는 게 좋아요

        var label: String {
            switch self {
            case .generallyOk: return "대체로 괜찮아요"
            case .moderate: return "주의가 필요해요"
            case .avoid: return "피하는 게 좋아요"
            }
        }

        /// SF Symbol(판정 아이콘 아님 · 시각 보조).
        var symbol: String {
            switch self {
            case .generallyOk: return "checkmark.circle"
            case .moderate: return "exclamationmark.triangle"
            case .avoid: return "hand.raised"
            }
        }
    }

    struct Item: Identifiable, Hashable {
        let id: String
        let name: String
        let level: Level
        /// 일반 안내문(주의 수준 + "의료진과 상의" 톤). 의학 단정 금지.
        let guidance: String
        /// 검색용 동의어·영문 키워드.
        let keywords: [String]
    }

    /// 한국 임산부가 자주 찾는 음식·약물 (의료감수 전 초안 · 참고용).
    static let items: [Item] = [
        .init(id: "caffeine", name: "커피·카페인", level: .moderate,
              guidance: "하루 카페인을 약 200mg(원두커피 1~2잔) 이내로 줄이도록 권장하는 안내가 많아요. 차·초콜릿·콜라에도 들어 있어요. 정확한 양은 담당 의료진과 상의하세요.",
              keywords: ["커피", "카페인", "coffee", "caffeine", "에너지드링크", "녹차", "홍차", "콜라"]),
        .init(id: "alcohol", name: "술·알코올", level: .avoid,
              guidance: "임신 중 안전한 음주량은 확립되어 있지 않아 피하도록 권장돼요. 요리에 넣은 알코올도 조리법에 따라 남을 수 있어요.",
              keywords: ["술", "알코올", "맥주", "와인", "소주", "alcohol", "음주"]),
        .init(id: "raw-fish", name: "회·생선회·날생선", level: .moderate,
              guidance: "생식은 식중독·기생충 위험이 있어 충분히 익혀 먹도록 권장하는 안내가 많아요. 섭취 여부는 의료진과 상의하세요.",
              keywords: ["회", "생선회", "날생선", "초밥", "스시", "sashimi", "sushi", "물회"]),
        .init(id: "high-mercury-fish", name: "큰 생선(수은 주의)", level: .moderate,
              guidance: "참치·상어 등 일부 큰 생선은 수은 함량이 높을 수 있어 섭취 빈도를 줄이도록 권장돼요. 종류·양은 의료진과 상의하세요.",
              keywords: ["참치", "수은", "상어", "고등어", "mercury", "tuna", "생선"]),
        .init(id: "raw-meat", name: "익히지 않은 고기·육회", level: .avoid,
              guidance: "톡소플라스마 등 감염 위험으로 고기는 충분히 익혀 먹도록 권장돼요.",
              keywords: ["육회", "날고기", "생고기", "레어", "raw meat", "스테이크"]),
        .init(id: "raw-egg", name: "날달걀·반숙", level: .moderate,
              guidance: "살모넬라 위험으로 완전히 익혀 먹도록 권장하는 안내가 많아요. 일부 소스·디저트에도 날달걀이 들어가요.",
              keywords: ["날달걀", "계란", "반숙", "마요네즈", "egg", "달걀"]),
        .init(id: "unpasteurized-dairy", name: "비살균 우유·연성치즈", level: .moderate,
              guidance: "리스테리아 위험으로 살균(파스퇴르) 제품·가열을 권장하는 안내가 많아요.",
              keywords: ["치즈", "우유", "비살균", "생우유", "연성치즈", "cheese", "유제품"]),
        .init(id: "deli-meat", name: "가공육·델리미트", level: .moderate,
              guidance: "햄·소시지 등은 가열 후 섭취를 권장하는 안내가 있어요.",
              keywords: ["햄", "소시지", "가공육", "델리미트", "베이컨", "ham"]),
        .init(id: "herbal-medicine", name: "한약·한방차", level: .moderate,
              guidance: "성분·체질에 따라 영향이 다를 수 있어 복용 전 한의사·담당 의료진과 상의하세요.",
              keywords: ["한약", "한방", "보약", "한방차", "herbal", "쌍화탕"]),
        .init(id: "otc-medicine", name: "일반의약품(해열·진통 등)", level: .moderate,
              guidance: "성분·임신 시기에 따라 권고가 달라요. 복용 전 의사·약사와 상의하세요. 자의로 중단·복용하지 마세요.",
              keywords: ["약", "진통제", "해열제", "타이레놀", "감기약", "medicine", "이부프로펜"]),
        .init(id: "folate-supplement", name: "엽산·철분 보충제", level: .generallyOk,
              guidance: "엽산 등은 임신 중 권장되는 경우가 많지만, 용량은 담당 의료진의 안내를 따르세요.",
              keywords: ["엽산", "철분", "영양제", "보충제", "비타민", "folate", "iron"]),
        .init(id: "cooked-food", name: "충분히 익힌 음식", level: .generallyOk,
              guidance: "충분히 가열·조리한 음식은 대체로 권장돼요. 위생적으로 보관·섭취하세요.",
              keywords: ["익힌", "조리", "가열", "cooked", "따뜻한"])
    ]

    static let disclaimer =
        "음식·약물 안전 정보는 일반적인 참고 자료예요. 개인의 건강 상태·복용 중인 약은 반드시 담당 의료진과 상의하세요."

    /// 이름·키워드 부분일치 검색(대소문자 무시). 빈/공백 질의는 전체 반환.
    static func search(_ query: String) -> [Item] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return items }
        return items.filter { item in
            item.name.lowercased().contains(q) || item.keywords.contains { $0.lowercased().contains(q) }
        }
    }
}

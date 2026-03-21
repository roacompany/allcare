import SwiftUI

// MARK: - DevelopmentCategory

enum DevelopmentCategory: String, CaseIterable, Identifiable {
    case play = "발달 자극 놀이"
    case sleep = "수면 교육"
    case mentalCare = "부모 멘탈 케어"
    case insight = "성장 인사이트"

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .play: "🎮"
        case .sleep: "🌙"
        case .mentalCare: "🧘"
        case .insight: "📊"
        }
    }

    var color: Color {
        switch self {
        case .play: AppColors.feedingColor
        case .sleep: AppColors.sleepColor
        case .mentalCare: AppColors.softPurpleColor
        case .insight: AppColors.indigoColor
        }
    }
}

// MARK: - DevelopmentCard

struct DevelopmentCard: Identifiable {
    let id: String
    let category: DevelopmentCategory
    let title: String
    let body: String
    let monthRange: ClosedRange<Int>
    let emoji: String

    /// 현재 월령이 적용 범위에 포함되는지 확인
    func isRecommended(for ageMonths: Int) -> Bool {
        monthRange.contains(ageMonths)
    }
}

// MARK: - Static Content Library

extension DevelopmentCard {
    // swiftlint:disable line_length
    static let all: [DevelopmentCard] = [

        // MARK: 발달 자극 놀이

        DevelopmentCard(
            id: "play_1",
            category: .play,
            title: "3개월 아기 시각 추적 놀이 3가지",
            body: "생후 3개월 아기는 시각 피질이 빠르게 발달하는 시기입니다. 첫째, 흑백 패턴 카드를 아기 얼굴에서 20~30cm 떨어진 곳에 놓고 천천히 좌우로 움직여 눈 추적을 유도하세요. 둘째, 빨간색 공을 아기 눈앞에서 원을 그리듯 이동시키면 눈 근육이 강화됩니다. 셋째, 모빌을 침대 위에 달아두면 스스로 색상과 움직임을 탐색하는 능력이 길러집니다. 하루 5~10분씩 2~3회 반복하되, 아기가 피곤해 보이면 즉시 중단하세요. 이 놀이들은 나중에 글자와 그림을 인식하는 기반이 됩니다.",
            monthRange: 2...4,
            emoji: "👁️"
        ),

        DevelopmentCard(
            id: "play_2",
            category: .play,
            title: "6개월 손 협응 놀이",
            body: "생후 6개월에는 양손 협응과 잡기 반사가 정교해집니다. 부드러운 천 블록이나 고무링을 아기 손에 쥐어주고 스스로 입으로 가져가는 탐색을 허용하세요(질식 위험 없는 크기 필수). 두 손에 각각 다른 장난감을 들게 한 뒤 한쪽에서 다른 쪽으로 옮기도록 유도하면 양손 협응 능력이 발달합니다. 물이 든 투명 페트병을 손에 쥐어주면 시각-촉각 통합 자극도 됩니다. 하루 10~15분씩 충분한 배밀이 시간도 확보해 주세요. 이 시기의 손 협응 발달은 이후 소근육 발달과 직접적으로 연결됩니다.",
            monthRange: 5...7,
            emoji: "🤲"
        ),

        DevelopmentCard(
            id: "play_3",
            category: .play,
            title: "9개월 까꿍 놀이의 인지 발달 효과",
            body: "까꿍 놀이는 단순한 놀이처럼 보이지만, '대상 영속성'이라는 핵심 인지 개념을 가르칩니다. 아기가 보이지 않아도 물체가 존재한다는 사실을 깨닫는 것이죠. 얼굴을 손으로 가렸다가 보여주거나, 장난감을 천 아래 숨겼다가 꺼내보여 주세요. 반응이 생기면 점점 복잡하게—천 두 장 사이에 숨기거나, 컵 세 개 중 하나 아래 장난감을 숨기는 방식으로 난이도를 올리세요. 이 활동은 기억력, 예측력, 집중력 발달에 직접적인 영향을 줍니다. 하루 5분씩만 해도 충분합니다.",
            monthRange: 8...10,
            emoji: "🎭"
        ),

        DevelopmentCard(
            id: "play_4",
            category: .play,
            title: "12개월 블록 쌓기 놀이",
            body: "돌 전후 아기는 쌓기와 무너뜨리기를 반복하며 인과관계를 배웁니다. 큰 소프트 블록 2~3개부터 시작해 쌓는 것을 직접 보여주고, 아기가 무너뜨리면 함께 환호해 주세요. 점차 다른 크기와 색의 블록을 섞어 넣으면 분류 개념도 생깁니다. 블록을 여러 줄로 늘어놓거나 상자 안에 넣었다 빼는 활동도 추가하면 공간 지각력이 발달합니다. 이 시기 쌓기 놀이는 이후 수학적 사고, 언어 발달, 사회적 협력과도 연관됩니다. 하루 15~20분이 적당합니다.",
            monthRange: 11...14,
            emoji: "🧱"
        ),

        DevelopmentCard(
            id: "play_5",
            category: .play,
            title: "18개월 모래·물 감각 놀이",
            body: "18개월 아기는 오감 탐색이 최고조에 달합니다. 작은 플라스틱 통에 쌀이나 물을 담아 손으로 파고, 붓고, 채우는 경험을 제공하세요. 이 단순한 활동이 감각 통합, 집중력, 소근육 발달을 동시에 자극합니다. 색소를 탄 물에 하얀 천을 담그고 물들이는 활동도 색 개념 학습에 좋습니다. 야외 모래놀이는 더욱 효과적이며, 모래성 쌓기는 창의력과 협동심을 기릅니다. 뒷정리를 함께 하면 책임감도 자연스럽게 익힙니다.",
            monthRange: 15...20,
            emoji: "🌊"
        ),

        // MARK: 수면 교육

        DevelopmentCard(
            id: "sleep_1",
            category: .sleep,
            title: "4개월 수면 퇴행기 대처법",
            body: "생후 4개월 전후에 많은 아기가 갑자기 수면 패턴이 흐트러지는 '수면 퇴행'을 겪습니다. 이는 수면 사이클이 성인과 비슷하게 재편되는 정상적인 과정입니다. 대처법: ① 취침 루틴(목욕→수유→자장가)을 일관되게 유지하세요. ② 졸리지만 깨어있을 때 눕히는 연습을 시작하세요. ③ 낮잠 주기를 1.5~2시간 간격으로 맞춰보세요. ④ 수면 환경을 어둡고 조용하게(혹은 백색소음)유지하세요. 퇴행기는 보통 2~6주 지속됩니다. 이 시기를 잘 넘기면 오히려 수면 연장 기회가 됩니다.",
            monthRange: 3...5,
            emoji: "😴"
        ),

        DevelopmentCard(
            id: "sleep_2",
            category: .sleep,
            title: "6개월 밤중 수유 끊기",
            body: "생후 6개월이 지나면 대부분의 아기는 영양 측면에서 밤중 수유 없이도 충분히 자는 것이 가능합니다. 단, 모유수유 아기는 영양 및 애착 측면에서 더 오래 밤중 수유를 할 수 있으며, 이는 정상입니다. 끊기 방법: ① 점진적 감소법—매 2~3일마다 수유량을 5~10ml씩 줄이거나 수유 시간을 줄여나가세요. ② 달래기 우선—울음이 시작되면 5~10분 후 접근해 수유 없이 토닥임, 노래로 재워보세요. ③ 취침 전 포만감 확보—마지막 수유를 넉넉하게 해주세요. 밤중 수유를 급격히 끊으면 스트레스가 크므로 2~3주의 여유를 두고 진행하세요. 낮 수유량은 충분히 유지해야 합니다.",
            monthRange: 5...8,
            emoji: "🌛"
        ),

        DevelopmentCard(
            id: "sleep_3",
            category: .sleep,
            title: "8개월 분리불안과 수면",
            body: "8~10개월 아기는 분리불안이 최고조에 달하며 이것이 수면 문제로 이어집니다. 핵심은 '아빠/엄마는 사라지지 않는다'는 믿음을 쌓는 것입니다. ① 낮 동안 짧은 이별 연습을 반복하고, 돌아올 때 반갑게 맞아주세요. ② 취침 루틴에 '잘 자' 인사를 포함시켜 이별의 의미를 학습시키세요. ③ 애착 인형이나 담요 등 '전환 대상'을 만들어 주세요. ④ 밤중에 깰 경우 즉시 안아들기보다 목소리로 먼저 안심시키세요. 이 시기는 일시적이며 보통 12개월 이후 호전됩니다.",
            monthRange: 7...11,
            emoji: "🤗"
        ),

        DevelopmentCard(
            id: "sleep_4",
            category: .sleep,
            title: "12개월 낮잠 전환",
            body: "돌 전후로 많은 아기가 하루 2회 낮잠에서 1회로 전환됩니다. 징후: 낮잠을 거부하거나 한쪽 낮잠에서 잘 자지 않음. 전환 방법: ① 아침 낮잠을 조금씩 늦춰 점심 시간(오전 11~12시)으로 맞추세요. ② 낮잠 총 시간 1.5~2.5시간을 유지하세요. ③ 전환 중에는 저녁 취침 시간을 일시적으로 30분 앞당기세요. 전환 기간(약 4~8주)에는 피곤함이 극에 달하는 오후에 짧은 낮잠이 필요할 수도 있습니다. 전환은 서두르지 말고 아기의 컨디션을 보며 조절하세요.",
            monthRange: 11...15,
            emoji: "☀️"
        ),

        // MARK: 부모 멘탈 케어

        DevelopmentCard(
            id: "mental_1",
            category: .mentalCare,
            title: "새벽 수유가 힘들 때 5분 마인드풀니스",
            body: "새벽 2시, 다시 깨어난 아기 앞에서 눈물이 날 때—5분 마인드풀니스로 버텨보세요. ① 수유 자세가 안정되면 눈을 감고 코로 4초 들이쉬고, 입으로 6초 내쉬기를 3회 반복하세요. ② 지금 느끼는 감각(아기의 온기, 냄새)에 의도적으로 집중하세요. ③ '나는 지금 최선을 다하고 있다'는 문장을 속으로 3번 되새기세요. 완벽하게 해내려 하지 않아도 됩니다. 이 고단함은 영원하지 않고, 지금 이 순간도 지나갑니다. 배우자에게 다음 타번을 요청하는 것도 용기 있는 선택입니다.",
            monthRange: 0...6,
            emoji: "🧘"
        ),

        DevelopmentCard(
            id: "mental_2",
            category: .mentalCare,
            title: "육아 번아웃 자가 진단",
            body: "아래 증상이 2주 이상 3가지 이상 해당된다면 번아웃 초기 신호입니다: ① 아기를 돌보는 것이 의무감으로만 느껴진다 ② 작은 일에도 극도로 짜증이 난다 ③ 잠을 자도 피로가 풀리지 않는다 ④ 즐거웠던 취미나 대화에 흥미가 없다 ⑤ 내가 좋은 부모인지 계속 의심된다. 대처: 하루 30분의 '나만의 시간'을 만들고, 가족/친구에게 도움을 요청하세요. 전문 상담사를 찾는 것은 약함이 아닌 현명한 선택입니다. 건강한 부모가 건강한 아기를 키웁니다.",
            monthRange: 0...24,
            emoji: "💆"
        ),

        DevelopmentCard(
            id: "mental_3",
            category: .mentalCare,
            title: "부부 육아 분담 대화법",
            body: "육아 갈등의 80%는 역할 불균형에서 시작됩니다. 효과적인 대화를 위한 3단계: ① 비난 없이 사실 공유—'나는 어젯밤 3번 깼어. 나는 너무 지쳐있어'처럼 '나' 언어를 사용하세요. ② 구체적인 분담 제안—'수요일 새벽은 네가 맡아줄 수 있어?'처럼 구체적으로 요청하세요. ③ 인정과 감사—상대방이 한 일을 구체적으로 인정해 주세요. 분담표를 함께 작성하는 것도 좋습니다. 완벽한 50:50보다 '내가 힘들 때 기댈 수 있다'는 신뢰가 더 중요합니다.",
            monthRange: 0...24,
            emoji: "💑"
        ),

        DevelopmentCard(
            id: "mental_4",
            category: .mentalCare,
            title: "완벽하지 않아도 괜찮아",
            body: "SNS에는 완벽해 보이는 육아 장면들이 넘쳐납니다. 하지만 그것은 하루 중 0.1%의 순간입니다. 실제 좋은 부모의 기준은 '충분히 좋은 부모(Good Enough Parent)'입니다. 소아과 의사 위니컷의 개념으로, 아이의 모든 요구에 완벽하게 응할 필요가 없으며, 70%만 잘 반응해도 아이는 건강하게 자랍니다. 중요한 것은: 아이에게 따뜻하게 대하려는 의도, 실수 후 관계 회복, 일관된 사랑의 표현입니다. 오늘 한 번 화냈다고 나쁜 부모가 되는 것이 아닙니다.",
            monthRange: 0...24,
            emoji: "💛"
        ),

        // MARK: 성장 인사이트

        DevelopmentCard(
            id: "insight_1",
            category: .insight,
            title: "또래 평균 수유량 비교",
            body: "월령별 평균 수유량 가이드라인입니다. 신생아(0~1개월): 초반 5~30ml에서 점차 60~90ml로 증가, 하루 8~12회. 2~3개월: 회당 120~150ml, 하루 6~8회. 4~6개월: 회당 150~200ml, 하루 5~6회. 6개월 이상(이유식 병행): 회당 150~180ml, 하루 4~5회. 단, 이 수치는 평균값이며 아기마다 차이가 큽니다. 중요한 것은 절대량보다 아기가 배고파하거나 과도하게 울지 않는지, 적절히 체중이 늘고 있는지 여부입니다. 걱정될 때는 소아과 의사와 상담하세요.",
            monthRange: 0...8,
            emoji: "🍼"
        ),

        DevelopmentCard(
            id: "insight_2",
            category: .insight,
            title: "수면 시간 월령별 변화",
            body: "아기의 수면 필요량은 월령에 따라 급격히 변합니다. 신생아(0~3개월): 총 14~17시간(낮밤 구분 없음). 4~11개월: 총 12~15시간(낮잠 3→2→1회로 감소). 1~2세: 총 11~14시간(낮잠 1회, 1.5~2시간). 이 범위에서 30~60분 차이는 정상입니다. 잠을 너무 적게 자는 아기는 오히려 과활성화되어 더 잠들기 어려워집니다. '일찍 재우면 일찍 깬다'는 통념과 달리, 적절한 취침 시간(오후 7~8시)이 밤잠을 더 길게 만드는 경우가 많습니다.",
            monthRange: 0...24,
            emoji: "⏰"
        ),

        DevelopmentCard(
            id: "insight_3",
            category: .insight,
            title: "체중 증가 패턴 이해",
            body: "건강한 체중 증가의 기준: 생후 1주(회복기 이후)~3개월: 주당 150~200g 증가. 3~6개월: 주당 100~150g. 6~12개월: 주당 70~90g. 생후 4~5개월에 출생 체중의 2배, 1세에 3배가 일반적입니다. 성장곡선 3~97백분위 사이라면 정상 범위입니다. 중요한 것은 절대 수치보다 '곡선의 방향'—지속적으로 자신의 백분위 선을 따라가는지 확인하세요. 한 달에 2백분위 이상 급격히 떨어지면 소아과 상담이 필요합니다.",
            monthRange: 0...12,
            emoji: "⚖️"
        ),

        DevelopmentCard(
            id: "insight_4",
            category: .insight,
            title: "대근육 발달 타임라인",
            body: "대근육 발달의 일반적인 순서와 시기입니다. 목 가누기: 3~4개월. 뒤집기: 4~6개월. 혼자 앉기: 6~8개월. 기기(복부/네발): 8~10개월. 잡고 서기: 9~11개월. 혼자 서기: 11~13개월. 걷기: 12~15개월. 단, 이 범위는 정상의 폭이며 3~4개월 차이는 흔합니다. 발달 순서가 중요하지 시기만 중요한 것은 아닙니다. 기기를 건너뛰고 바로 걷는 아기도 있습니다. 18개월까지 혼자 걷지 못하거나 발달이 퇴보한다면 소아과 상담을 권장합니다.",
            monthRange: 0...18,
            emoji: "🏃"
        ),

        DevelopmentCard(
            id: "insight_5",
            category: .insight,
            title: "언어 발달 이정표 체크",
            body: "언어 발달 정상 범위입니다. 2개월: 사회적 미소, 쿠잉(구구 소리). 4개월: 웃음소리, 다양한 소리 반응. 6개월: 옹알이 시작('바바', '마마'). 9개월: 의도 없는 '마마/바바' 반복. 12개월: 1~2개 의미 있는 단어 사용. 18개월: 10~20개 단어. 24개월: 2단어 조합('엄마 줘', '아빠 가'). 걱정 신호: 12개월에 옹알이 없음, 16개월에 단어 없음, 24개월에 2단어 조합 없음, 어느 시기든 언어 능력이 퇴보. 이런 경우 소아청소년과 또는 언어치료사 상담을 권장합니다.",
            monthRange: 0...24,
            emoji: "💬"
        )
    ]
    // swiftlint:enable line_length

    /// 특정 월령에 추천되는 카드 필터링
    static func recommended(for ageMonths: Int) -> [DevelopmentCard] {
        all.filter { $0.isRecommended(for: ageMonths) }
    }

    /// 카테고리로 필터링
    static func cards(for category: DevelopmentCategory) -> [DevelopmentCard] {
        all.filter { $0.category == category }
    }
}

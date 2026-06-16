import Foundation

/// 한국 표준 산전검진 항목의 현재 주차 대비 상태.
enum PrenatalScheduleStatus: Hashable {
    case past      // 권장 시기가 지남
    case current   // 현재 권장 시기(윈도우 안)
    case future    // 아직 다가오지 않음
}

/// 한국 표준 산전검진 항목 1개 (의료감수 전 초안 데이터, 참고용).
struct KoreanPrenatalScheduleItem: Identifiable, Hashable {
    let id: String
    let title: String
    let weekStart: Int
    let weekEnd: Int
    let summary: String
    let note: String?
}

/// 타임라인 노드 = 항목 + 현재 주차 대비 상태.
struct PrenatalTimelineNode: Identifiable, Hashable {
    let item: KoreanPrenatalScheduleItem
    let status: PrenatalScheduleStatus
    var id: String { item.id }
}

/// 한국 표준 산전검진 일정 — 주차 자동 매핑(순수·테스트 대상).
///
/// ⚠️ 의료감수 전 초안(`.dev/specs/pregnancy-mode-v3/context/prenatal-data.md`). 시기·내용은
/// 출처·병원·산모 위험도에 따라 달라지는 "권장 범위"이며 의학적 판단을 대체하지 않는다(면책 배너 동반).
/// 접종(Tdap·독감)은 검진이 아니므로 제외 — 분류는 후속 PO 판단(prenatal-data.md 감수주의 #6).
enum KoreanPrenatalSchedule {

    static let standardItems: [KoreanPrenatalScheduleItem] = [
        .init(id: "early-basic", title: "초기 기본검사", weekStart: 5, weekEnd: 10,
              summary: "혈액형·빈혈·감염(B형간염·풍진 등)·소변 기본검사", note: "첫 내원 시"),
        .init(id: "nt-first", title: "NT·1차 기형아 선별", weekStart: 11, weekEnd: 13,
              summary: "목덜미 투명대 초음파 + 모체혈청 선별", note: "11주~13주 6일"),
        .init(id: "quad-second", title: "쿼드·2차 기형아 선별", weekStart: 15, weekEnd: 20,
              summary: "모체혈액 4종 호르몬 선별", note: nil),
        .init(id: "detailed-ultrasound", title: "정밀초음파", weekStart: 18, weekEnd: 24,
              summary: "태아 주요 장기·구조 정밀 관찰", note: "약 20주(출처별 18~24주)"),
        .init(id: "gdm-screening", title: "임신성 당뇨 선별(GTT)", weekStart: 24, weekEnd: 28,
              summary: "50g 경구당부하 선별검사", note: "양성 시 100g 정밀검사"),
        .init(id: "gbs-screening", title: "GBS(B군 연쇄구균) 선별", weekStart: 35, weekEnd: 37,
              summary: "질·직장 도말 배양(분만 중 항생제 판단)", note: nil),
        .init(id: "term-predelivery", title: "분만 전 검사", weekStart: 37, weekEnd: 40,
              summary: "막달 종합검사(혈액·응고 등 분만 대비)", note: nil)
    ]

    /// 정기 진찰 간격 안내(KSOG/아이사랑 통념). 고정 규칙 아님 — "권장" 표기.
    static let checkupIntervalNote =
        "정기 진찰은 보통 28주까지 4주마다, 28~36주 2주마다, 이후 매주 권장돼요. (병원·산모 상태에 따라 달라요)"

    /// 항목 1개의 현재 주차 대비 상태. 주차 미상(nil)이면 `.future`(타임라인은 보이되 "지금 여기"는 숨김).
    static func status(for item: KoreanPrenatalScheduleItem, currentWeek: Int?) -> PrenatalScheduleStatus {
        guard let week = currentWeek else { return .future }
        if week > item.weekEnd { return .past }
        if week < item.weekStart { return .future }
        return .current
    }

    /// 주차순 정렬된 타임라인 노드(항목 + 상태).
    static func timeline(currentWeek: Int?) -> [PrenatalTimelineNode] {
        standardItems
            .sorted { $0.weekStart < $1.weekStart }
            .map { PrenatalTimelineNode(item: $0, status: status(for: $0, currentWeek: currentWeek)) }
    }

    /// 현재 주차가 속한 첫 권장창 항목(없으면 nil — 히어로/마커용).
    static func currentItem(currentWeek: Int?) -> KoreanPrenatalScheduleItem? {
        guard currentWeek != nil else { return nil }
        return timeline(currentWeek: currentWeek).first { $0.status == .current }?.item
    }
}

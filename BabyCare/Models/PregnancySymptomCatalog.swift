import Foundation

/// 임신 증상 추천칩 카탈로그 — 한국 임신부가 흔히 기록하는 증상 용어.
///
/// ⚠️ 의학적 판단/원인 추정 금지 — 입력 편의용 칩일 뿐, 빈도/추이만 시각화한다.
/// ⚠️ 응급 가능 증상(urgent)은 앱이 위험도를 판정하지 않고 '의료진 연락' 비진단 안내만 노출한다.
/// ⚠️ 큐레이션 데이터(증상·주차 범위)는 **의료감수 전 초안**. 주차 범위는 일반적 경향이며 개인차가 크다.
enum PregnancySymptomCatalog {

    struct Chip: Identifiable, Equatable {
        let label: String
        /// 흔하게 나타나는 주차 범위. nil = 전 기간.
        let weekRange: ClosedRange<Int>?
        /// 응급 가능 여부 — true면 비진단 '의료진 연락' 안내 대상.
        var isUrgent: Bool = false
        var id: String { label }
    }

    /// 흔한 증상 (입력 편의용 추천칩). 응급 가능 증상은 `urgent`로 분리.
    static let common: [Chip] = [
        Chip(label: "입덧", weekRange: 4...16),
        Chip(label: "가슴 뭉침·통증", weekRange: 4...16),
        Chip(label: "피로", weekRange: nil),
        Chip(label: "변비", weekRange: nil),
        Chip(label: "분비물 증가", weekRange: nil),
        Chip(label: "두통", weekRange: nil),
        Chip(label: "속쓰림·명치 답답함", weekRange: 14...40),
        Chip(label: "요통", weekRange: 16...40),
        Chip(label: "치골통·골반통", weekRange: 20...40),
        Chip(label: "다리 쥐", weekRange: 20...40),
        Chip(label: "부종", weekRange: 24...40),
        Chip(label: "불면", weekRange: 24...40)
    ]

    /// 응급 가능 증상 — 선택 시 비진단 '의료진 연락' 안내(`urgentNotice`) 노출. 위험도 판정 안 함.
    static let urgent: [Chip] = [
        Chip(label: "질 출혈", weekRange: nil, isUrgent: true),
        Chip(label: "심한 복통", weekRange: nil, isUrgent: true),
        Chip(label: "물 같은 분비물(양수 의심)", weekRange: nil, isUrgent: true),
        Chip(label: "심한 두통+시야 흐림", weekRange: nil, isUrgent: true),
        Chip(label: "태동 급감", weekRange: 24...42, isUrgent: true),
        Chip(label: "38도 이상 고열", weekRange: nil, isUrgent: true)
    ]

    /// 응급 가능 증상 안내(비진단). 위험도 판정 없이 의료진 연락만 권고.
    static let urgentNotice = "이런 증상이 있으면 스스로 판단하지 말고 즉시 병원이나 산모수첩의 응급 연락처로 연락하세요. 앱은 위험도를 판정하지 않아요."

    /// 현재 주차에 흔한 증상 추천칩 (응급 제외). weekRange가 nil이면 전 기간 노출.
    static func recommended(forWeek week: Int) -> [Chip] {
        common.filter { chip in
            guard let range = chip.weekRange else { return true }
            return range.contains(week)
        }
    }
}

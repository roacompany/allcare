import Foundation

/// 국민행복카드 임신·출산 진료비 바우처 안내(순수 정적 데이터).
/// ⚠️ 의료감수/정책 변동 전 초안(`prenatal-data.md`, 2024 확대분 기준). 앱 노출 시 "최신은 정부24/공단 확인" 병기.
/// 앱은 카드사 미연동 — 안내·금액 정보만, 커머스/결제 링크 0.
enum HappyCardVoucher {

    /// 지원 한도(원): 단태 100만 / 다태(2명+) 140만 / 분만취약지 거주 +20만.
    static func supportAmount(fetusCount: Int?, isRemoteArea: Bool = false) -> Int {
        let base = (fetusCount ?? 1) >= 2 ? 1_400_000 : 1_000_000
        return base + (isRemoteArea ? 200_000 : 0)
    }

    /// 수동 입력 사용액 대비 사용 진행률 0...1 (총액 0·음수 방어, 초과는 1.0 클램프).
    static func usedProgress(used: Int, total: Int) -> Double {
        guard total > 0 else { return 0 }
        return min(1.0, Double(max(0, used)) / Double(total))
    }

    /// 남은 금액(원). 음수 방지(초과 사용 시 0).
    static func remaining(used: Int, total: Int) -> Int {
        max(0, total - max(0, used))
    }

    /// 사용액이 총 지원액을 초과했는지(경고 라벨용).
    static func isOverBudget(used: Int, total: Int) -> Bool {
        used > total
    }

    static let usageNote =
        "병·의원·약국 등 요양기관에서 진료비·처방 약제 구입에 사용해요. (미용·건강보조식품 등은 제외)"
    static let periodNote =
        "분만예정일(출산 후 신청 시 출산일)부터 2년 이내 사용, 미사용 잔액은 자동 소멸돼요."
    static let applyNote =
        "정부24 '맘편한임신' 또는 국민건강보험공단·카드사(국민행복카드 위탁사)에서 신청해요."
    static let disclaimer =
        "실제 잔액·지원 자격은 정부24·국민건강보험공단·카드사에서 확인하세요."
}

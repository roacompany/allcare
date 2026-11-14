import Foundation

/// 위젯 → 앱 주소(한 곳). 위젯은 여기서 주소를 받고, 앱(`DeepLinkRouter`)은 같은 표를 푼다.
/// 위젯 확장도 이 파일을 같이 컴파일한다(project.yml `BabyCareWidgetExtension.sources`).
///
/// 🩸 2026-11-14: 위젯이 주소를 손으로 적어 앱이 모르는 주소가 생겼다 — 「오늘 요약」(dashboard)·성장(health/growth)·
/// 임신(pregnancy) 위젯은 눌러도 앱만 열렸다. 위젯에 새 주소가 필요하면 여기에 더하고 `DeepLinkRouter` 에서 푼다
/// (시험 `WidgetLinkTests` 가 표의 모든 주소가 앱에서 어딘가로 열리는지 본다).
enum WidgetLink: String, CaseIterable, Sendable {
    /// 기록하기(칸을 고르지 않음)
    case record = "babycare://record"
    case recordFeeding = "babycare://record/feeding"
    case recordSleep = "babycare://record/sleep"
    case recordDiaper = "babycare://record/diaper"
    /// 홈 — 「오늘 요약」 위젯 · 잠금 화면 한 줄
    case home = "babycare://dashboard"
    /// 건강 › 성장기록 — 성장 백분위 위젯
    case growth = "babycare://health/growth"
    /// 임신 D-day 위젯
    case pregnancy = "babycare://pregnancy"

    var url: URL { URL(string: rawValue)! }
}

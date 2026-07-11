import Foundation

/// 주간 요약 푸시 본문 생성 (UX Clean Sweep C6).
/// 기존 주간 리포트 알림은 정적 문구였다 — 지난 7일 기록을 실제 카운트로 요약해
/// "이번 주 ○○이 기록 N건 — 수유 x · 수면 y · 기저귀 z"로 만든다.
/// 의료 단정/압박 없는 중립 요약(safety.md).
enum WeeklySummaryPolicy {
    /// 지난 7일 활동 → 요약 본문. 기록이 없으면 nil(호출부가 generic 문구로 폴백).
    static func summaryLine(babyName: String, weekActivities: [Activity]) -> String? {
        guard !weekActivities.isEmpty else { return nil }

        let feeding = weekActivities.filter { $0.type.category == .feeding }.count
        let sleep = weekActivities.filter { $0.type == .sleep }.count
        let diaper = weekActivities.filter { $0.type.category == .diaper }.count
        let total = weekActivities.count

        var parts: [String] = []
        if feeding > 0 { parts.append("수유 \(feeding)") }
        if sleep > 0 { parts.append("수면 \(sleep)") }
        if diaper > 0 { parts.append("기저귀 \(diaper)") }

        let head = "이번 주 \(babyName) 기록 \(total)건"
        return parts.isEmpty ? head : "\(head) — \(parts.joined(separator: " · "))"
    }
}

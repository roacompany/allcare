import Foundation

extension Array where Element == WeeklyMetricSnapshot {
    /// Z-score 기준선 history 에서 현재 분석 주차를 제외 (자기오염 방지 #11).
    /// 같은 주차 스냅샷이 이전 대시보드 오픈에서 저장돼 history 에 섞이면
    /// 현재 값이 자기 자신과 비교돼 편차(이상치 점수)가 깎인다.
    /// (스파크라인 표시용 snapshots 는 현재 주차를 유지 — 차트엔 이번 주 점이 보여야 함.)
    func excludingWeek(_ weekKey: String) -> [WeeklyMetricSnapshot] {
        filter { $0.weekKey != weekKey }
    }
}

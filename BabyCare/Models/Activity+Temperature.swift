import Foundation

extension Sequence where Element == Activity {
    /// 체온 통계용 — `.temperature` 타입 기록만 추린다.
    /// forward-compat `.unknown` 센티넬은 형제 필드(temperature 등)를 보존하므로,
    /// `temperature != nil` 같은 필드-필터로 집계하면 미래 스키마의 온도가 발열 집계·병원 리포트로 샌다.
    /// 타입-필터로 격리한다 (2026-06-10 감사 #1/#4, swift-conventions.md "전수순회 .unknown 필터 필수").
    var temperatureActivities: [Activity] {
        filter { $0.type == .temperature }
    }
}

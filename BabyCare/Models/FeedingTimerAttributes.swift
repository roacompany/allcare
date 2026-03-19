import ActivityKit
import Foundation

/// Live Activity 수유 타이머용 ActivityAttributes
/// 메인 앱과 위젯 Extension에서 공유
struct FeedingTimerAttributes: ActivityAttributes {
    /// 정적 데이터: Activity 시작 시 설정, 변경 불가
    public struct ContentState: Codable, Hashable {
        /// 현재 경과 시간 (초) — 업데이트마다 갱신
        var elapsedSeconds: Int
        /// 타이머 활성 여부
        var isRunning: Bool
    }

    /// 아기 이름
    var babyName: String
    /// 수유 유형 표시명 (모유수유, 분유 등)
    var feedingTypeDisplay: String
    /// 수유 유형 아이콘 (SF Symbol)
    var feedingTypeIcon: String
    /// 타이머 시작 시각
    var startTime: Date
    /// 최대 자동 종료 시간 (8시간)
    static let maxDurationSeconds: Int = 8 * 3600
}

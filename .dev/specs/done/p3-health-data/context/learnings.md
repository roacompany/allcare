## TODO 1
- Swift 6.0: enum 타입 PercentileCalculator → Sendable 문제 없음
- BabyCareTests는 단일 파일에 모든 테스트 append
- 남아 3mo 6.0kg = ~30.3th (M=6.3762), 명세의 45-55 범위는 중앙값 기준

## TODO 3
- ActivityViewModel @MainActor — 테스트도 @MainActor 필요
- NotificationSettings: nonisolated(unsafe) static UserDefaults 패턴
- timeInterval: 1 for trend alert (reactive to save)

## TODO 4
- Simulator cold-start → signal kill; 재실행 시 성공
- fetchAllergyRecords: date descending

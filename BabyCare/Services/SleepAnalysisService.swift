import Foundation

// MARK: - SleepAnalysisResult

struct SleepAnalysisResult {
    var regressionWarning: SleepRegressionWarning?
    var optimalBedtime: OptimalBedtime?
    var napNightRatios: [NapNightRatio]?
    var qualityScore: SleepQualityScore?
}

// MARK: - SleepAnalysisService

/// 수면 데이터에서 능동적 인사이트를 추출하는 단일 책임 서비스.
/// 1. 수면 퇴행 자동 감지
/// 2. 최적 취침 시간 추천
/// 3. 낮잠 vs 밤잠 비율 트렌드
/// 4. 수면 품질 점수 (0~100)
///
/// - Note: 이 서비스의 결과는 정보 제공 목적이며 의학적 진단이 아닙니다.
enum SleepAnalysisService {

    // MARK: - Constants

    /// 낮/밤 경계: 06~18시를 낮으로 간주
    static let napStartHour = 6
    static let napEndHour = 18

    /// 수면 퇴행 감지 월령 (±2주 윈도우)
    static let regressionAgeMonths: [Int] = [4, 8, 12]
    static let regressionWindowDays = 14

    // MARK: - Static API

    /// 수면 활동 리스트에서 4가지 인사이트를 한번에 계산합니다.
    static func analyze(sleepActivities: [Activity]) -> SleepAnalysisResult {
        SleepAnalysisResult(
            regressionWarning: detectRegression(sleepActivities: sleepActivities),
            optimalBedtime: computeOptimalBedtime(sleepActivities: sleepActivities),
            napNightRatios: computeNapNightRatios(sleepActivities: sleepActivities),
            qualityScore: computeQualityScore(sleepActivities: sleepActivities)
        )
    }

    // MARK: - 1. 수면 퇴행 감지

    /// 최근 7일 평균 수면이 직전 14~28일 평균 대비 -20% 이상이면 경고를 반환합니다.
    /// 아기 탄생일 정보 없이 활동 기간만으로 판단 (호출부에서 월령 필터 적용 권고).
    static func detectRegression(sleepActivities: [Activity]) -> SleepRegressionWarning? {
        let calendar = Calendar.current
        let now = Date()

        // 최근 7일
        guard let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: now) else { return nil }
        let recentSleeps = sleepActivities.filter { $0.startTime >= sevenDaysAgo }
        let recentHours = recentSleeps.compactMap(\.duration).reduce(0, +) / 3600
        let recentAvg = recentHours / 7.0

        // 직전 14~28일 (7일 이전 ~ 28일 이전)
        guard let twentyEightDaysAgo = calendar.date(byAdding: .day, value: -28, to: now) else { return nil }
        let baselineSleeps = sleepActivities.filter {
            $0.startTime >= twentyEightDaysAgo && $0.startTime < sevenDaysAgo
        }
        guard !baselineSleeps.isEmpty else { return nil }
        let baselineDays = Double(max(1, calendar.dateComponents(
            [.day], from: twentyEightDaysAgo, to: sevenDaysAgo
        ).day ?? 21))
        let baselineHours = baselineSleeps.compactMap(\.duration).reduce(0, +) / 3600
        let baselineAvg = baselineHours / baselineDays

        guard baselineAvg > 0 else { return nil }

        let declineRate = (recentAvg - baselineAvg) / baselineAvg
        // -0.20 이하 (20% 이상 감소)
        guard declineRate <= -0.20 else { return nil }

        return SleepRegressionWarning(
            regressionAgeMonth: nil,  // 호출부에서 아기 월령 기반으로 세팅 가능
            recentAvgHours: recentAvg,
            baselineAvgHours: baselineAvg,
            declineRate: declineRate
        )
    }

    /// 아기 월령을 추가로 받아 퇴행 감지 + 해당 월령 윈도우 라벨링을 합니다.
    static func detectRegression(
        sleepActivities: [Activity],
        babyAgeMonths: Int
    ) -> SleepRegressionWarning? {
        guard var warning = detectRegression(sleepActivities: sleepActivities) else { return nil }

        // 4/8/12개월 ±2주 윈도우 판정
        let matchedAge = regressionAgeMonths.first { ageMonth in
            let diffMonths = abs(babyAgeMonths - ageMonth)
            // ±2주 ≒ ±0.5개월, 여기서는 1개월 이내로 완화
            return diffMonths <= 1
        }
        warning.regressionAgeMonth = matchedAge ?? babyAgeMonths
        return warning
    }

    // MARK: - 2. 최적 취침 시간 추천

    /// 최근 7일 밤잠 시작 시각 중앙값 ± 30분 윈도우를 반환합니다.
    /// 밤잠: 18시 이후 또는 06시 이전 시작 수면
    static func computeOptimalBedtime(sleepActivities: [Activity]) -> OptimalBedtime? {
        let calendar = Calendar.current
        let now = Date()
        guard let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: now) else { return nil }

        // 밤잠 필터: 최근 7일, 18시 이후 또는 6시 이전
        let nightSleeps = sleepActivities.filter { act in
            guard act.startTime >= sevenDaysAgo else { return false }
            let hour = calendar.component(.hour, from: act.startTime)
            return hour >= napEndHour || hour < napStartHour
        }
        guard !nightSleeps.isEmpty else { return nil }

        // 시작 시각을 자정 기준 초로 변환
        let bedtimeSeconds: [TimeInterval] = nightSleeps.map { act in
            let hour = Double(calendar.component(.hour, from: act.startTime))
            let minute = Double(calendar.component(.minute, from: act.startTime))
            var seconds = hour * 3600 + minute * 60
            // 자정~06시는 다음날로 보정 (예: 01:00 → 25:00)
            if hour < Double(napStartHour) {
                seconds += 24 * 3600
            }
            return seconds
        }

        let sorted = bedtimeSeconds.sorted()
        let median: TimeInterval
        let mid = sorted.count / 2
        if sorted.count % 2 == 0 {
            median = (sorted[mid - 1] + sorted[mid]) / 2
        } else {
            median = sorted[mid]
        }

        let windowHalf: TimeInterval = 30 * 60  // 30분
        return OptimalBedtime(
            bedtimeStart: median - windowHalf,
            bedtimeEnd: median + windowHalf,
            medianBedtime: median,
            sampleCount: nightSleeps.count
        )
    }

    // MARK: - 3. 낮잠 vs 밤잠 비율 트렌드

    /// 일별 낮잠/밤잠 시간 비율을 반환합니다 (낮 기준 06~18시).
    static func computeNapNightRatios(sleepActivities: [Activity]) -> [NapNightRatio] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: sleepActivities) {
            calendar.startOfDay(for: $0.startTime)
        }

        return grouped.map { date, acts in
            let napHours = acts.filter { act in
                let hour = calendar.component(.hour, from: act.startTime)
                return hour >= napStartHour && hour < napEndHour
            }.compactMap(\.duration).reduce(0, +) / 3600

            let nightHours = acts.filter { act in
                let hour = calendar.component(.hour, from: act.startTime)
                return hour < napStartHour || hour >= napEndHour
            }.compactMap(\.duration).reduce(0, +) / 3600

            let totalHours = napHours + nightHours
            let napRatio = totalHours > 0 ? napHours / totalHours : 0.0

            return NapNightRatio(
                date: date,
                napHours: napHours,
                nightHours: nightHours,
                napRatio: napRatio
            )
        }.sorted { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }
    }

    // MARK: - 4. 수면 품질 점수 (0~100)

    /// 가중치: 총수면시간(50) + 깨는 횟수 역수(30) + 낮잠 횟수 적정성(20)
    /// - 총수면시간: 일평균 14시간 기준 (신생아 기준, 개월수에 따라 조정 없음)
    /// - 깨는 횟수: duration이 없는 sleep 세션은 짧은 깨어남으로 간주
    /// - 낮잠 횟수: 일평균 2~3회를 적정으로 간주
    static func computeQualityScore(sleepActivities: [Activity]) -> SleepQualityScore? {
        guard !sleepActivities.isEmpty else { return nil }

        let calendar = Calendar.current
        let days = Set(sleepActivities.map { calendar.startOfDay(for: $0.startTime) }).count
        let effectiveDays = max(1, days)

        // 총수면시간 점수 (50점 만점)
        let totalHours = sleepActivities.compactMap(\.duration).reduce(0, +) / 3600
        let avgDailyHours = totalHours / Double(effectiveDays)
        // 목표: 14시간/일 기준 (0~14+ → 0~50점)
        let targetHours = 14.0
        let durationRatio = min(1.0, avgDailyHours / targetHours)
        let durationScore = Int(durationRatio * 50)

        // 깨는 횟수 역수 점수 (30점 만점)
        // duration이 30분 미만인 수면을 짧은 각성으로 간주
        let shortSessions = sleepActivities.filter { ($0.duration ?? 0) < 1800 }.count
        let wakesPerDay = Double(shortSessions) / Double(effectiveDays)
        // 0회/일 → 30점, 5회+/일 → 0점
        let wakeScore: Int
        switch wakesPerDay {
        case ..<1:    wakeScore = 30
        case 1..<2:   wakeScore = 24
        case 2..<3:   wakeScore = 18
        case 3..<4:   wakeScore = 12
        case 4..<5:   wakeScore = 6
        default:      wakeScore = 0
        }

        // 낮잠 횟수 적정성 점수 (20점 만점)
        let napSessions = sleepActivities.filter { act in
            let hour = calendar.component(.hour, from: act.startTime)
            return hour >= napStartHour && hour < napEndHour
        }.count
        let napsPerDay = Double(napSessions) / Double(effectiveDays)
        // 2~3회/일 적정 → 20점
        let napScore: Int
        switch napsPerDay {
        case 2..<3:   napScore = 20
        case 1..<2, 3..<4: napScore = 14
        case 0..<1:   napScore = 8
        default:      napScore = 6
        }

        let totalScore = durationScore + wakeScore + napScore

        return SleepQualityScore(
            score: totalScore,
            durationScore: durationScore,
            wakeScore: wakeScore,
            napScore: napScore,
            avgDailyHours: avgDailyHours,
            totalSessions: sleepActivities.count
        )
    }

    // MARK: - Helpers

    /// TimeInterval(자정 기준 초)을 "HH:mm" 포맷 문자열로 변환합니다.
    static func formatBedtimeSeconds(_ seconds: TimeInterval) -> String {
        let normalizedSeconds = seconds.truncatingRemainder(dividingBy: 86400)
        let hours = Int(normalizedSeconds / 3600) % 24
        let minutes = Int(normalizedSeconds.truncatingRemainder(dividingBy: 3600)) / 60
        return String(format: "%02d:%02d", hours, minutes)
    }
}

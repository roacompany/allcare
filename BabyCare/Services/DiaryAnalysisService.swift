import Foundation

// MARK: - Diary Analysis Service

/// 일기 데이터에서 월간 요약, N개월 전 오늘 회고, 기분 트렌드를 계산하는 정적 유틸리티 서비스.
/// PatternAnalysisService 패턴을 따릅니다 (enum static, 외부 의존 없음).
enum DiaryAnalysisService {

    // MARK: - Monthly Summary

    /// 지정한 year/month 에 속하는 일기들로 월간 요약을 계산합니다.
    static func monthlyDistribution(
        entries: [DiaryEntry],
        year: Int,
        month: Int
    ) -> MonthlyMoodDistribution {
        let calendar = Calendar.current
        let filtered = entries.filter {
            let comps = calendar.dateComponents([.year, .month], from: $0.date)
            return comps.year == year && comps.month == month
        }

        let totalEntries = filtered.count

        var moodCounts: [String: Int] = [:]
        for entry in filtered {
            if let mood = entry.mood {
                moodCounts[mood.rawValue, default: 0] += 1
            }
        }

        // 일기 작성 일수 (중복 날짜 제거)
        let writtenDays = Set(filtered.map {
            calendar.startOfDay(for: $0.date)
        }).count

        // 평균 글자 수
        let averageContentLength: Double = totalEntries > 0
            ? Double(filtered.reduce(0) { $0 + $1.content.count }) / Double(totalEntries)
            : 0

        return MonthlyMoodDistribution(
            year: year,
            month: month,
            totalEntries: totalEntries,
            moodCounts: moodCounts,
            writtenDays: writtenDays,
            averageContentLength: averageContentLength
        )
    }

    // MARK: - Throwback

    /// 오늘로부터 N개월 전 같은 날짜에 해당하는 일기들을 회고 카드 형식으로 반환합니다.
    /// 일기가 없는 N개월은 결과에 포함되지 않습니다.
    static func throwbackEntries(
        entries: [DiaryEntry],
        monthOffsets: [Int] = [1, 3, 6, 12],
        referenceDate: Date = Date()
    ) -> [ThrowbackEntry] {
        let calendar = Calendar.current
        var result: [ThrowbackEntry] = []

        for offset in monthOffsets {
            guard let targetDate = calendar.date(byAdding: .month, value: -offset, to: referenceDate) else { continue }
            let targetComps = calendar.dateComponents([.year, .month, .day], from: targetDate)

            // 같은 날짜의 일기 중 첫 번째 사용
            if let match = entries.first(where: {
                let c = calendar.dateComponents([.year, .month, .day], from: $0.date)
                return c.year == targetComps.year && c.month == targetComps.month && c.day == targetComps.day
            }) {
                result.append(ThrowbackEntry(id: match.id, monthsAgo: offset, entry: match))
            }
        }

        return result
    }

    // MARK: - Mood Trend

    /// 최근 N개월의 기분 분포 트렌드를 계산합니다 (차트용).
    static func moodTrends(
        entries: [DiaryEntry],
        monthCount: Int = 6,
        referenceDate: Date = Date()
    ) -> [MoodTrend] {
        let calendar = Calendar.current
        var result: [MoodTrend] = []

        for monthOffset in (0..<monthCount).reversed() {
            guard let targetDate = calendar.date(byAdding: .month, value: -monthOffset, to: referenceDate) else { continue }
            let comps = calendar.dateComponents([.year, .month], from: targetDate)
            guard let year = comps.year, let month = comps.month else { continue }

            let distribution = monthlyDistribution(entries: entries, year: year, month: month)
            guard distribution.totalEntries > 0 else { continue }

            for (moodRaw, count) in distribution.moodCounts {
                let ratio = distribution.totalEntries > 0
                    ? Double(count) / Double(distribution.totalEntries)
                    : 0
                result.append(MoodTrend(
                    year: year,
                    month: month,
                    mood: moodRaw,
                    count: count,
                    ratio: ratio
                ))
            }
        }

        return result
    }

    // MARK: - Photo URLs

    /// 모든 일기에서 사진 URL이 있는 (entry, url) 쌍을 추출합니다 (갤러리용).
    static func allPhotoItems(from entries: [DiaryEntry]) -> [(entry: DiaryEntry, url: String)] {
        entries.flatMap { entry in
            entry.photoURLs.map { (entry: entry, url: $0) }
        }
    }
}

import Foundation

/// 기념일 카운트다운 정책 (UX Clean Sweep C4).
/// 50일·백일·200일·300일·돌(이후 생일 포함)을 계산해 임박(D-7 이내) 시 대시보드에 노출 —
/// 실측(2026-07-11): 기존에 기념일 기능 부재.
enum AnniversaryPolicy {
    struct Anniversary: Equatable {
        let title: String
        let date: Date
        /// 남은 일수 (0 = 오늘).
        let dDay: Int
    }

    /// 카드 노출 윈도우 — 기념일 D-7 이내.
    static let visibleWindowDays = 7

    /// 다음 기념일 (지난 것 제외, 가장 가까운 1개). 관례: 백일 = 출생일 포함 100번째 날(생일+99일), 돌 = 첫 생일.
    static func next(birthDate: Date, now: Date, calendar: Calendar = .current) -> Anniversary? {
        let birthDay = calendar.startOfDay(for: birthDate)
        let today = calendar.startOfDay(for: now)

        var candidates: [(title: String, date: Date)] = []
        let dayMilestones: [(String, Int)] = [("50일", 49), ("백일", 99), ("200일", 199), ("300일", 299)]
        for (title, offset) in dayMilestones {
            if let date = calendar.date(byAdding: .day, value: offset, to: birthDay) {
                candidates.append((title, date))
            }
        }
        for year in 1...30 {
            if let date = calendar.date(byAdding: .year, value: year, to: birthDay) {
                let title = year == 1 ? "첫돌" : year == 2 ? "두 돌" : "\(year)번째 생일"
                candidates.append((title, date))
            }
        }

        return candidates
            .compactMap { title, date -> Anniversary? in
                let dDay = calendar.dateComponents([.day], from: today, to: calendar.startOfDay(for: date)).day ?? 0
                return dDay >= 0 ? Anniversary(title: title, date: date, dDay: dDay) : nil
            }
            .min(by: { $0.dDay < $1.dDay })
    }

    /// 대시보드 카드 노출 여부 — 다음 기념일이 D-7 이내일 때만.
    static func visible(birthDate: Date, now: Date, calendar: Calendar = .current) -> Anniversary? {
        guard let upcoming = next(birthDate: birthDate, now: now, calendar: calendar),
              upcoming.dDay <= visibleWindowDays else { return nil }
        return upcoming
    }
}

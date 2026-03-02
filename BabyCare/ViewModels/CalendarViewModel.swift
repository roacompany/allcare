import Foundation

@MainActor @Observable
final class CalendarViewModel {
    var selectedDate = Date()
    var currentMonth = Date()
    var activitiesForDate: [Activity] = []
    var activityDots: [Date: Set<Activity.ActivityCategory>] = [:]
    var isLoading = false

    private let firestoreService = FirestoreService.shared

    var daysInMonth: [Date] {
        let calendar = Calendar.current
        guard let range = calendar.range(of: .day, in: .month, for: currentMonth),
              let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth))
        else { return [] }

        return range.compactMap { day in
            calendar.date(byAdding: .day, value: day - 1, to: firstDay)
        }
    }

    var firstWeekdayOfMonth: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: currentMonth)
        guard let firstDay = calendar.date(from: components) else { return 0 }
        return (calendar.component(.weekday, from: firstDay) + 5) % 7 // Mon = 0
    }

    var monthTitle: String {
        DateFormatters.yearMonth.string(from: currentMonth)
    }

    func previousMonth() {
        currentMonth = Calendar.current.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
    }

    func nextMonth() {
        currentMonth = Calendar.current.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
    }

    func selectDate(_ date: Date) {
        selectedDate = date
    }

    func loadMonthActivities(userId: String, babyId: String) async {
        let calendar = Calendar.current
        guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth)),
              let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)
        else { return }

        isLoading = true
        do {
            let activities = try await firestoreService.fetchActivities(
                userId: userId, babyId: babyId,
                from: startOfMonth.startOfDay, to: endOfMonth.endOfDay
            )

            var dots: [Date: Set<Activity.ActivityCategory>] = [:]
            for activity in activities {
                let day = activity.startTime.startOfDay
                var categories = dots[day] ?? []
                categories.insert(activity.type.category)
                dots[day] = categories
            }
            activityDots = dots
        } catch {
            // silently fail
        }
        isLoading = false
    }

    func loadActivitiesForDate(userId: String, babyId: String) async {
        isLoading = true
        do {
            activitiesForDate = try await firestoreService.fetchActivities(
                userId: userId, babyId: babyId, date: selectedDate
            )
        } catch {
            activitiesForDate = []
        }
        isLoading = false
    }
}

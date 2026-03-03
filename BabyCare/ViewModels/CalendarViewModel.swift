import Foundation

/// 캘린더에 표시되는 이벤트 유형
enum CalendarEventType: Hashable {
    case activity(Activity.ActivityCategory)
    case hospitalVisit
    case vaccination
    case todo
}

@MainActor @Observable
final class CalendarViewModel {
    var selectedDate = Date()
    var currentMonth = Date()
    var activitiesForDate: [Activity] = []
    var hospitalVisitsForDate: [HospitalVisit] = []
    var vaccinationsForDate: [Vaccination] = []
    var todosForDate: [TodoItem] = []
    var eventDots: [Date: Set<CalendarEventType>] = [:]
    var isLoading = false
    var isLoadingDate = false
    var errorMessage: String?

    private let firestoreService = FirestoreService.shared
    private var allMonthHospitalVisits: [HospitalVisit] = []
    private var allMonthVaccinations: [Vaccination] = []
    private var allTodos: [TodoItem] = []

    // MARK: - Daily Summary (선택 날짜 기준)

    var feedingCount: Int {
        activitiesForDate.filter { $0.type.category == .feeding }.count
    }

    var sleepHours: Double {
        activitiesForDate.filter { $0.type == .sleep }
            .compactMap(\.duration).reduce(0, +) / 3600
    }

    var diaperCount: Int {
        activitiesForDate.filter { $0.type.category == .diaper }.count
    }

    var totalMl: Double {
        activitiesForDate.filter { $0.type.category == .feeding }
            .compactMap(\.amount).reduce(0, +)
    }

    var hasDailySummary: Bool {
        !activitiesForDate.isEmpty
    }

    // MARK: - Computed Calendar Properties

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

    var isCurrentMonth: Bool {
        Calendar.current.isDate(currentMonth, equalTo: Date(), toGranularity: .month)
    }

    // MARK: - Navigation

    func previousMonth() {
        currentMonth = Calendar.current.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
    }

    func nextMonth() {
        currentMonth = Calendar.current.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
    }

    func goToToday() {
        currentMonth = Date()
        selectedDate = Date()
    }

    func selectDate(_ date: Date) {
        selectedDate = date
    }

    // MARK: - Data Loading

    func loadMonthActivities(userId: String, babyId: String) async {
        let calendar = Calendar.current
        guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth)),
              let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)
        else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            async let fetchActs = firestoreService.fetchActivities(
                userId: userId, babyId: babyId,
                from: startOfMonth.startOfDay, to: endOfMonth.endOfDay
            )
            async let fetchVisits = firestoreService.fetchHospitalVisits(userId: userId, babyId: babyId)
            async let fetchVax = firestoreService.fetchVaccinations(userId: userId, babyId: babyId)
            async let fetchTodos = firestoreService.fetchTodos(userId: userId)

            let (activities, visits, vaccinations, todos) = try await (fetchActs, fetchVisits, fetchVax, fetchTodos)

            allMonthHospitalVisits = visits
            allMonthVaccinations = vaccinations
            allTodos = todos

            var dots: [Date: Set<CalendarEventType>] = [:]

            for activity in activities {
                let day = activity.startTime.startOfDay
                dots[day, default: []].insert(.activity(activity.type.category))
            }

            for visit in visits {
                let day = visit.visitDate.startOfDay
                if day >= startOfMonth.startOfDay && day <= endOfMonth.endOfDay {
                    dots[day, default: []].insert(.hospitalVisit)
                }
                if let next = visit.nextVisitDate {
                    let nextDay = next.startOfDay
                    if nextDay >= startOfMonth.startOfDay && nextDay <= endOfMonth.endOfDay {
                        dots[nextDay, default: []].insert(.hospitalVisit)
                    }
                }
            }

            for vax in vaccinations {
                let scheduledDay = vax.scheduledDate.startOfDay
                if scheduledDay >= startOfMonth.startOfDay && scheduledDay <= endOfMonth.endOfDay {
                    dots[scheduledDay, default: []].insert(.vaccination)
                }
                if let administered = vax.administeredDate {
                    let admDay = administered.startOfDay
                    if admDay >= startOfMonth.startOfDay && admDay <= endOfMonth.endOfDay {
                        dots[admDay, default: []].insert(.vaccination)
                    }
                }
            }

            // 할 일 dots
            for todo in todos {
                if let dueDate = todo.dueDate {
                    let day = dueDate.startOfDay
                    if day >= startOfMonth.startOfDay && day <= endOfMonth.endOfDay {
                        dots[day, default: []].insert(.todo)
                    }
                }
            }

            eventDots = dots
        } catch {
            errorMessage = "캘린더 데이터를 불러오지 못했습니다."
        }
    }

    func loadActivitiesForDate(userId: String, babyId: String) async {
        isLoadingDate = true
        defer { isLoadingDate = false }

        let selectedDay = selectedDate.startOfDay

        do {
            activitiesForDate = try await firestoreService.fetchActivities(
                userId: userId, babyId: babyId, date: selectedDate
            )
        } catch {
            activitiesForDate = []
            errorMessage = "해당 날짜의 기록을 불러오지 못했습니다."
        }

        hospitalVisitsForDate = allMonthHospitalVisits.filter {
            $0.visitDate.startOfDay == selectedDay ||
            ($0.nextVisitDate?.startOfDay == selectedDay)
        }.sorted { $0.visitDate < $1.visitDate }

        vaccinationsForDate = allMonthVaccinations.filter {
            $0.scheduledDate.startOfDay == selectedDay ||
            ($0.administeredDate?.startOfDay == selectedDay)
        }.sorted { $0.scheduledDate < $1.scheduledDate }

        todosForDate = allTodos.filter {
            $0.dueDate?.startOfDay == selectedDay
        }.sorted { ($0.isCompleted ? 1 : 0) < ($1.isCompleted ? 1 : 0) }
    }
}

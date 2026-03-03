import EventKit
import OSLog

@MainActor
final class CalendarService {
    static let shared = CalendarService()
    private let store = EKEventStore()
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "BabyCare", category: "Calendar")

    private init() {}

    // MARK: - Authorization

    var isAuthorized: Bool {
        EKEventStore.authorizationStatus(for: .event) == .fullAccess
    }

    func requestAccess() async -> Bool {
        do {
            return try await store.requestFullAccessToEvents()
        } catch {
            Self.logger.error("Calendar access request failed: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Hospital Visit

    func addHospitalVisit(_ visit: HospitalVisit, babyName: String) async -> Bool {
        guard await ensureAccess() else { return false }

        let event = EKEvent(eventStore: store)
        event.title = "[\(babyName)] \(visit.visitType.displayName) - \(visit.hospitalName)"
        event.startDate = visit.visitDate
        event.endDate = Calendar.current.date(byAdding: .hour, value: 1, to: visit.visitDate) ?? visit.visitDate
        event.calendar = store.defaultCalendarForNewEvents

        var notes: [String] = []
        if let dept = visit.department { notes.append("진료과: \(dept)") }
        if let doctor = visit.doctorName { notes.append("담당의: \(doctor)") }
        if let purpose = visit.purpose { notes.append("방문 사유: \(purpose)") }
        if !notes.isEmpty { event.notes = notes.joined(separator: "\n") }

        event.addAlarm(EKAlarm(relativeOffset: -3600)) // 1시간 전
        event.addAlarm(EKAlarm(relativeOffset: -86400)) // 1일 전

        return saveEvent(event, id: "hospital_\(visit.id)")
    }

    func addNextVisit(from visit: HospitalVisit, babyName: String) async -> Bool {
        guard let nextDate = visit.nextVisitDate else { return false }
        guard await ensureAccess() else { return false }

        let event = EKEvent(eventStore: store)
        event.title = "[\(babyName)] 재방문 - \(visit.hospitalName)"
        event.startDate = nextDate
        event.endDate = Calendar.current.date(byAdding: .hour, value: 1, to: nextDate) ?? nextDate
        event.calendar = store.defaultCalendarForNewEvents
        event.notes = "이전 방문: \(DateFormatters.shortDate.string(from: visit.visitDate))"
        event.addAlarm(EKAlarm(relativeOffset: -3600))
        event.addAlarm(EKAlarm(relativeOffset: -86400))

        return saveEvent(event, id: "hospital_next_\(visit.id)")
    }

    // MARK: - Vaccination

    func addVaccination(_ vaccination: Vaccination, babyName: String) async -> Bool {
        guard await ensureAccess() else { return false }

        let event = EKEvent(eventStore: store)
        event.title = "[\(babyName)] 예방접종 - \(vaccination.vaccine.displayName) \(vaccination.doseNumber)차"
        event.startDate = vaccination.scheduledDate
        event.endDate = Calendar.current.date(byAdding: .hour, value: 1, to: vaccination.scheduledDate) ?? vaccination.scheduledDate
        event.calendar = store.defaultCalendarForNewEvents
        event.isAllDay = true
        event.addAlarm(EKAlarm(relativeOffset: -86400)) // 1일 전
        event.addAlarm(EKAlarm(relativeOffset: -259200)) // 3일 전

        return saveEvent(event, id: "vax_\(vaccination.id)")
    }

    // MARK: - Remove

    func removeEvent(id: String) {
        guard isAuthorized else { return }
        let predicate = store.predicateForEvents(
            withStart: Date.distantPast,
            end: Date.distantFuture,
            calendars: nil
        )
        let events = store.events(matching: predicate)
        for event in events where event.notes?.contains("BabyCareID:\(id)") == true {
            do {
                try store.remove(event, span: .thisEvent)
            } catch {
                Self.logger.warning("Failed to remove calendar event: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Private

    private func ensureAccess() async -> Bool {
        if isAuthorized { return true }
        return await requestAccess()
    }

    private func saveEvent(_ event: EKEvent, id: String) -> Bool {
        // ID 태그 추가 (삭제 시 찾기 위해)
        let existingNotes = event.notes ?? ""
        event.notes = existingNotes.isEmpty ? "BabyCareID:\(id)" : "\(existingNotes)\n\nBabyCareID:\(id)"

        do {
            try store.save(event, span: .thisEvent)
            Self.logger.info("Calendar event saved: \(id)")
            return true
        } catch {
            Self.logger.error("Failed to save calendar event: \(error.localizedDescription)")
            return false
        }
    }
}

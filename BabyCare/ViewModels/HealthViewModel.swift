import Foundation

@MainActor @Observable
final class HealthViewModel {
    var vaccinations: [Vaccination] = []
    var milestones: [Milestone] = []
    var hospitalVisits: [HospitalVisit] = []
    var isLoading = false
    var errorMessage: String?

    private var currentBabyName: String = "아기"
    private let firestoreService = FirestoreService.shared

    // MARK: - Computed: Vaccinations

    var upcomingVaccinations: [Vaccination] {
        let now = Date()
        let in30Days = Calendar.current.date(byAdding: .day, value: 30, to: now) ?? now
        return vaccinations.filter {
            !$0.isCompleted && $0.scheduledDate >= now && $0.scheduledDate <= in30Days
        }
    }

    var overdueVaccinations: [Vaccination] {
        vaccinations.filter { $0.isOverdue }
    }

    var completedVaccinations: [Vaccination] {
        vaccinations.filter { $0.isCompleted }
    }

    // MARK: - Computed: Milestones

    var achievedMilestones: [Milestone] {
        milestones.filter { $0.isAchieved }
    }

    var pendingMilestones: [Milestone] {
        milestones.filter { !$0.isAchieved }
    }

    // MARK: - Computed: Hospital Visits

    var upcomingVisits: [HospitalVisit] {
        hospitalVisits.filter { $0.isUpcoming }
            .sorted { $0.visitDate < $1.visitDate }
    }

    var pastVisits: [HospitalVisit] {
        hospitalVisits.filter { $0.isPast }
    }

    var nextVisit: HospitalVisit? {
        upcomingVisits.first
    }

    // MARK: - Load

    func loadAll(userId: String, babyId: String, babyName: String = "아기") async {
        currentBabyName = babyName
        isLoading = true
        defer { isLoading = false }

        do {
            async let vaxResult = firestoreService.fetchVaccinations(userId: userId, babyId: babyId)
            async let msResult = firestoreService.fetchMilestones(userId: userId, babyId: babyId)
            async let hvResult = firestoreService.fetchHospitalVisits(userId: userId, babyId: babyId)
            let (vax, ms, hv) = try await (vaxResult, msResult, hvResult)
            vaccinations = vax
            milestones = ms
            hospitalVisits = hv
            scheduleVaccinationReminders(babyName: babyName)
        } catch {
            errorMessage = "건강 정보를 불러오지 못했습니다: \(error.localizedDescription)"
        }
    }

    // MARK: - Vaccination Actions

    func markVaccinationComplete(
        _ vaccination: Vaccination,
        administeredDate: Date,
        userId: String
    ) async {
        var updated = vaccination
        updated.isCompleted = true
        updated.administeredDate = administeredDate

        // Optimistic update
        if let idx = vaccinations.firstIndex(where: { $0.id == vaccination.id }) {
            vaccinations[idx] = updated
        }

        do {
            try await firestoreService.saveVaccination(updated, userId: userId)
        } catch {
            // Rollback
            if let idx = vaccinations.firstIndex(where: { $0.id == vaccination.id }) {
                vaccinations[idx] = vaccination
            }
            errorMessage = "접종 기록 저장에 실패했습니다: \(error.localizedDescription)"
        }
    }

    func undoVaccinationComplete(_ vaccination: Vaccination, userId: String) async {
        var updated = vaccination
        updated.isCompleted = false
        updated.administeredDate = nil

        // Optimistic update
        if let idx = vaccinations.firstIndex(where: { $0.id == vaccination.id }) {
            vaccinations[idx] = updated
        }

        do {
            try await firestoreService.saveVaccination(updated, userId: userId)
        } catch {
            // Rollback
            if let idx = vaccinations.firstIndex(where: { $0.id == vaccination.id }) {
                vaccinations[idx] = vaccination
            }
            errorMessage = "접종 취소에 실패했습니다: \(error.localizedDescription)"
        }
    }

    // MARK: - Milestone Actions

    func toggleMilestone(_ milestone: Milestone, userId: String, achievedDate: Date? = nil) async {
        var updated = milestone
        updated.isAchieved = !milestone.isAchieved
        updated.achievedDate = updated.isAchieved ? (achievedDate ?? Date()) : nil

        // Optimistic update
        if let idx = milestones.firstIndex(where: { $0.id == milestone.id }) {
            milestones[idx] = updated
        }

        do {
            try await firestoreService.saveMilestone(updated, userId: userId)
        } catch {
            // Rollback
            if let idx = milestones.firstIndex(where: { $0.id == milestone.id }) {
                milestones[idx] = milestone
            }
            errorMessage = "이정표 저장에 실패했습니다: \(error.localizedDescription)"
        }
    }

    // MARK: - Schedule Generation

    func generateScheduleIfNeeded(babyId: String, birthDate: Date, userId: String, babyName: String = "아기") async {
        let needVax = vaccinations.isEmpty
        let needMs = milestones.isEmpty
        guard needVax || needMs else { return }

        let generatedVax = needVax ? Vaccination.generateSchedule(babyId: babyId, birthDate: birthDate) : []
        let generatedMs = needMs ? Milestone.generateChecklist(babyId: babyId) : []

        // Optimistic update
        if needVax { vaccinations = generatedVax }
        if needMs { milestones = generatedMs }

        do {
            if needVax {
                try await firestoreService.saveVaccinations(generatedVax, userId: userId)
            }
            if needMs {
                try await firestoreService.saveMilestones(generatedMs, userId: userId)
            }
            scheduleVaccinationReminders(babyName: babyName)
        } catch {
            if needVax { vaccinations = [] }
            if needMs { milestones = [] }
            errorMessage = "스케줄 생성에 실패했습니다: \(error.localizedDescription)"
        }
    }

    // MARK: - Hospital Visit Actions

    func saveHospitalVisit(_ visit: HospitalVisit, userId: String) async {
        // Optimistic update
        if let idx = hospitalVisits.firstIndex(where: { $0.id == visit.id }) {
            hospitalVisits[idx] = visit
        } else {
            hospitalVisits.append(visit)
            hospitalVisits.sort { $0.visitDate > $1.visitDate }
        }

        RecentHospitals.add(visit.hospitalName)

        do {
            try await firestoreService.saveHospitalVisit(visit, userId: userId)
            // D-1 알림 예약 (예정된 방문만)
            let targetDate = visit.scheduledDate ?? visit.visitDate
            if targetDate > Date() {
                NotificationService.shared.scheduleHospitalVisitReminder(visit: visit, babyName: currentBabyName)
            }
        } catch {
            hospitalVisits.removeAll { $0.id == visit.id }
            errorMessage = "병원 기록 저장에 실패했습니다: \(error.localizedDescription)"
        }
    }

    func deleteHospitalVisit(_ visit: HospitalVisit, userId: String) async {
        let original = hospitalVisits
        hospitalVisits.removeAll { $0.id == visit.id }

        do {
            try await firestoreService.deleteHospitalVisit(visit.id, userId: userId, babyId: visit.babyId)
            NotificationService.shared.cancelHospitalVisitReminder(visitId: visit.id)
        } catch {
            hospitalVisits = original
            errorMessage = "병원 기록 삭제에 실패했습니다: \(error.localizedDescription)"
        }
    }

    // MARK: - Vaccination Reminders

    private func scheduleVaccinationReminders(babyName: String) {
        let upcoming = vaccinations.filter { !$0.isCompleted && $0.scheduledDate > Date() }
        NotificationService.shared.scheduleVaccinationReminders(vaccinations: upcoming, babyName: babyName)
    }
}

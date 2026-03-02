import Foundation

@MainActor @Observable
final class HealthViewModel {
    var vaccinations: [Vaccination] = []
    var milestones: [Milestone] = []
    var isLoading = false
    var errorMessage: String?

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

    // MARK: - Load

    func loadAll(userId: String, babyId: String, babyName: String = "아기") async {
        isLoading = true
        defer { isLoading = false }

        do {
            async let vaxResult = firestoreService.fetchVaccinations(userId: userId, babyId: babyId)
            async let msResult = firestoreService.fetchMilestones(userId: userId, babyId: babyId)
            let (vax, ms) = try await (vaxResult, msResult)
            vaccinations = vax
            milestones = ms
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

    // MARK: - Milestone Actions

    func toggleMilestone(_ milestone: Milestone, userId: String) async {
        var updated = milestone
        updated.isAchieved = !milestone.isAchieved
        updated.achievedDate = updated.isAchieved ? Date() : nil

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
        guard vaccinations.isEmpty else { return }

        let generatedVax = Vaccination.generateSchedule(babyId: babyId, birthDate: birthDate)
        let generatedMs = Milestone.generateChecklist(babyId: babyId)

        // Optimistic update
        vaccinations = generatedVax
        milestones = generatedMs

        do {
            async let saveVax: Void = firestoreService.saveVaccinations(generatedVax, userId: userId)
            async let saveMs: Void = firestoreService.saveMilestones(generatedMs, userId: userId)
            _ = try await (saveVax, saveMs)
            scheduleVaccinationReminders(babyName: babyName)
        } catch {
            vaccinations = []
            milestones = []
            errorMessage = "예방접종 스케줄 생성에 실패했습니다: \(error.localizedDescription)"
        }
    }

    // MARK: - Vaccination Reminders

    private func scheduleVaccinationReminders(babyName: String) {
        let upcoming = vaccinations.filter { !$0.isCompleted && $0.scheduledDate > Date() }
        NotificationService.shared.scheduleVaccinationReminders(vaccinations: upcoming, babyName: babyName)
    }
}

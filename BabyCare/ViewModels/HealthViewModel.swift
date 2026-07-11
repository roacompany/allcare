import Foundation

@MainActor @Observable
final class HealthViewModel: LoadingStateful, OptimisticReplaceable {
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
            .sorted { $0.scheduledDate < $1.scheduledDate }
    }

    /// 앱 사용 전(일정 생성 전)에 예정일이 지난 미기록 접종 — 지연 경고 대신 기록 안내 대상
    var unrecordedPastVaccinations: [Vaccination] {
        vaccinations.filter { $0.isUnrecordedPast }
            .sorted { $0.scheduledDate < $1.scheduledDate }
    }

    var completedVaccinations: [Vaccination] {
        vaccinations.filter { $0.isCompleted }
    }

    /// 다음 미완료 접종 (예정일 기준 가장 가까운 것)
    var nextVaccination: Vaccination? {
        vaccinations
            .filter { !$0.isCompleted && $0.scheduledDate >= Calendar.current.startOfDay(for: Date()) }
            .sorted { $0.scheduledDate < $1.scheduledDate }
            .first
    }

    /// 완료율 (0.0 ~ 1.0)
    var vaccinationCompletionRate: Double {
        guard !vaccinations.isEmpty else { return 0 }
        return Double(completedVaccinations.count) / Double(vaccinations.count)
    }

    /// 완료 카운트 텍스트 e.g. "8/14 완료 (57%)"
    var vaccinationCompletionText: String {
        let total = vaccinations.count
        let done = completedVaccinations.count
        let pct = total > 0 ? Int((Double(done) / Double(total)) * 100) : 0
        return String(
            format: NSLocalizedString("vaccination.progress.text", comment: ""),
            done, total, pct
        )
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

    var recentHospitalNames: [String] {
        Array(Set(hospitalVisits.map(\.hospitalName).filter { !$0.isEmpty })).sorted()
    }

    // MARK: - Load

    func loadAll(userId: String, babyId: String, babyName: String = "아기") async {
        currentBabyName = babyName
        await withLoading {
            do {
                let (vax, ms, hv) = try await RetryHelper.withRetry {
                    async let vaxResult = self.firestoreService.fetchVaccinations(userId: userId, babyId: babyId)
                    async let msResult = self.firestoreService.fetchMilestones(userId: userId, babyId: babyId)
                    async let hvResult = self.firestoreService.fetchHospitalVisits(userId: userId, babyId: babyId)
                    return try await (vaxResult, msResult, hvResult)
                }
                vaccinations = vax
                milestones = ms
                hospitalVisits = hv
                scheduleVaccinationReminders(babyName: babyName)
            } catch {
                logSilent("건강 정보를 불러오지 못했습니다", error: error, logger: AppLogger.firestore)
                errorMessage = "건강 정보를 불러오지 못했습니다. 잠시 후 다시 시도해 주세요."
            }
        }
    }

    // MARK: - Vaccination Actions

    func markVaccinationComplete(
        _ vaccination: Vaccination,
        administeredDate: Date,
        userId: String
    ) async {
        // 중복 접종 방지: 같은 백신 + 같은 차수가 이미 완료된 경우
        let isDuplicate = vaccinations.contains { v in
            v.vaccine == vaccination.vaccine &&
            v.doseNumber == vaccination.doseNumber &&
            v.id != vaccination.id &&
            v.isCompleted
        }
        guard !isDuplicate else {
            errorMessage = "이미 완료된 접종입니다. (\(vaccination.vaccine.displayName) \(vaccination.doseNumber)차)"
            return
        }

        var updated = vaccination
        updated.isCompleted = true
        updated.administeredDate = administeredDate

        if await optimisticReplace(
            in: \.vaccinations, original: vaccination, with: updated,
            save: { try await self.firestoreService.saveVaccination(updated, userId: userId) }
        ) != nil {
            queueHealthSaveOffline(updated, collection: FirestoreCollections.vaccinations, babyId: updated.babyId, documentId: updated.id, userId: userId)
            reapply(updated, in: \.vaccinations)
        }
    }

    /// 미기록 과거 접종 일괄 완료 (접종일=예정일). 사용자가 확인 다이얼로그를 거친 경우에만 호출.
    func markAllUnrecordedPastComplete(userId: String) async {
        let backfilled = Vaccination.completedBackfill(of: vaccinations)
        guard !backfilled.isEmpty else { return }

        let original = vaccinations
        for item in backfilled {
            if let idx = vaccinations.firstIndex(where: { $0.id == item.id }) {
                vaccinations[idx] = item
            }
        }

        do {
            try await firestoreService.saveVaccinations(backfilled, userId: userId)
        } catch {
            vaccinations = original
            logSilent("지난 접종 일괄 기록에 실패했습니다", error: error, logger: AppLogger.firestore)
            errorMessage = "지난 접종 일괄 기록에 실패했습니다. 잠시 후 다시 시도해 주세요."
        }
    }

    func undoVaccinationComplete(_ vaccination: Vaccination, userId: String) async {
        var updated = vaccination
        updated.isCompleted = false
        updated.administeredDate = nil

        if await optimisticReplace(
            in: \.vaccinations, original: vaccination, with: updated,
            save: { try await self.firestoreService.saveVaccination(updated, userId: userId) }
        ) != nil {
            queueHealthSaveOffline(updated, collection: FirestoreCollections.vaccinations, babyId: updated.babyId, documentId: updated.id, userId: userId)
            reapply(updated, in: \.vaccinations)
        }
    }

    /// optimisticReplace 실패(rollback 후) 시 낙관 상태 재적용 — 오프라인 큐 적재분을 화면에 유지.
    private func reapply<Item: Identifiable>(_ item: Item, in keyPath: ReferenceWritableKeyPath<HealthViewModel, [Item]>) {
        if let idx = self[keyPath: keyPath].firstIndex(where: { $0.id == item.id }) {
            self[keyPath: keyPath][idx] = item
        }
    }

    /// 오프라인 저장 폴백 — 연결 복구 시 자동 동기화 (Activity 큐 경로와 동일 계약).
    private func queueHealthSaveOffline(
        _ document: some Encodable,
        collection: String,
        babyId: String,
        documentId: String,
        userId: String,
        type: PendingOperation.OperationType = .update
    ) {
        let path = FirestoreCollections.babyChildPath(userId: userId, babyId: babyId, collection: collection)
        if !OfflineQueue.shared.enqueueSave(document, collectionPath: path, documentId: documentId, type: type) {
            AppLogger.firestore.error("오프라인 큐 인코딩 실패 — \(collection)/\(documentId) 큐잉 누락")
        }
        InfoToastCenter.shared.offlineSaved()
    }

    // MARK: - Milestone Actions

    func toggleMilestone(_ milestone: Milestone, userId: String, achievedDate: Date? = nil) async {
        var updated = milestone
        updated.isAchieved = !milestone.isAchieved
        updated.achievedDate = updated.isAchieved ? (achievedDate ?? Date()) : nil

        if await optimisticReplace(
            in: \.milestones, original: milestone, with: updated,
            save: { try await self.firestoreService.saveMilestone(updated, userId: userId) }
        ) != nil {
            queueHealthSaveOffline(updated, collection: FirestoreCollections.milestones, babyId: updated.babyId, documentId: updated.id, userId: userId)
            reapply(updated, in: \.milestones)
        }
    }

    func updateMilestoneDate(_ milestone: Milestone, achievedDate: Date, userId: String) async {
        var updated = milestone
        updated.achievedDate = achievedDate

        if await optimisticReplace(
            in: \.milestones, original: milestone, with: updated,
            save: { try await self.firestoreService.saveMilestone(updated, userId: userId) }
        ) != nil {
            queueHealthSaveOffline(updated, collection: FirestoreCollections.milestones, babyId: updated.babyId, documentId: updated.id, userId: userId)
            reapply(updated, in: \.milestones)
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
            logSilent("스케줄 생성에 실패했습니다", error: error, logger: AppLogger.firestore)
            errorMessage = "스케줄 생성에 실패했습니다. 잠시 후 다시 시도해 주세요."
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
            // 오프라인 폴백: 큐 적재 + 낙관 유지. D-1 리마인더는 로컬 알림이라 그대로 예약.
            queueHealthSaveOffline(visit, collection: FirestoreCollections.hospitalVisits, babyId: visit.babyId, documentId: visit.id, userId: userId, type: .create)
            let targetDate = visit.scheduledDate ?? visit.visitDate
            if targetDate > Date() {
                NotificationService.shared.scheduleHospitalVisitReminder(visit: visit, babyName: currentBabyName)
            }
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
            logSilent("병원 기록 삭제에 실패했습니다", error: error, logger: AppLogger.firestore)
            errorMessage = "병원 기록 삭제에 실패했습니다. 잠시 후 다시 시도해 주세요."
        }
    }

    // MARK: - Vaccination Reminders

    private func scheduleVaccinationReminders(babyName: String) {
        let upcoming = vaccinations.filter { !$0.isCompleted && $0.scheduledDate > Date() }
        NotificationService.shared.scheduleVaccinationReminders(vaccinations: upcoming, babyName: babyName)
        NotificationService.shared.scheduleSteppedVaccinationReminders(vaccinations: upcoming, babyName: babyName)
    }

    // MARK: - Allergy Records

    var allergyRecords: [AllergyRecord] = []

    // MARK: - Solid Food Activities (최근 90일 fetch — FoodSafety 분류용)

    var solidFoodActivities: [Activity] = []

    func loadRecentSolidFoods(userId: String, babyId: String) async {
        let ninetyDaysAgo = Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? Date()
        do {
            let activities = try await firestoreService.fetchActivities(
                userId: userId, babyId: babyId, from: ninetyDaysAgo, to: Date()
            )
            solidFoodActivities = activities.filter { $0.type == .feedingSolid }
        } catch {
            logSilent("이유식 기록 로드 실패", error: error, logger: AppLogger.firestore)
            errorMessage = "이유식 기록 로드 실패. 잠시 후 다시 시도해 주세요."
        }
    }

    // MARK: - Food Safety Computed

    /// 이유식 활동 + 알레르기 기록을 결합한 식품 안전 분류 목록
    var foodSafetyEntries: [FoodSafetyEntry] {
        FoodSafetyService.buildEntries(activities: solidFoodActivities, allergyRecords: allergyRecords)
    }

    /// 특정 식품의 시도 히스토리 타임라인
    func foodHistory(for foodName: String) -> [FoodHistoryEvent] {
        FoodSafetyService.buildHistory(
            foodName: foodName,
            activities: solidFoodActivities,
            allergyRecords: allergyRecords
        )
    }

    // MARK: - Auto-Suggest Helper

    /// 이유식 저장 후 알레르기 자동 생성 제안이 필요한지 판단
    func shouldSuggestAllergyFromSolidFood(_ activity: Activity) -> Bool {
        FoodSafetyService.shouldSuggestAllergyRecord(for: activity)
    }

    /// 제안 알레르기 레코드 템플릿 생성 (사용자가 내용을 확인 후 저장)
    func suggestAllergyRecord(from activity: Activity, babyId: String) -> AllergyRecord? {
        guard let foodName = activity.foodName, !foodName.isEmpty else { return nil }
        let severity: AllergySeverity = activity.foodReaction == .allergy ? .mild : .mild
        return AllergyRecord(
            babyId: babyId,
            allergenName: foodName,
            reactionType: .other,
            severity: severity,
            date: activity.startTime,
            symptoms: [],
            note: activity.note
        )
    }

    func loadAllergyRecords(userId: String, babyId: String) async {
        await withLoading {
            do {
                allergyRecords = try await firestoreService.fetchAllergyRecords(userId: userId, babyId: babyId)
            } catch {
                logSilent("알레르기 기록을 불러오지 못했습니다", error: error, logger: AppLogger.firestore)
                errorMessage = "알레르기 기록을 불러오지 못했습니다. 잠시 후 다시 시도해 주세요."
            }
        }
    }

    func saveAllergyRecord(_ record: AllergyRecord, userId: String, babyId: String) async throws {
        do {
            try await firestoreService.saveAllergyRecord(record, userId: userId, babyId: babyId)
        } catch {
            queueHealthSaveOffline(record, collection: FirestoreCollections.allergies, babyId: babyId, documentId: record.id, userId: userId, type: .create)
        }
    }

    func deleteAllergyRecord(userId: String, babyId: String, recordId: String) async {
        do {
            try await firestoreService.deleteAllergyRecord(recordId, userId: userId, babyId: babyId)
            allergyRecords.removeAll { $0.id == recordId }
        } catch {
            logSilent("알레르기 기록 삭제에 실패했습니다", error: error, logger: AppLogger.firestore)
            errorMessage = "알레르기 기록 삭제에 실패했습니다. 잠시 후 다시 시도해 주세요."
        }
    }

    // MARK: - Hospital Reminders (Form-level)

    func scheduleHospitalReminder(visitId: String, hospitalName: String, visitDate: Date) {
        NotificationService.shared.scheduleHospitalReminder(
            visitId: visitId,
            hospitalName: hospitalName,
            visitDate: visitDate
        )
    }

    func cancelHospitalReminder(visitId: String) {
        NotificationService.shared.cancelHospitalReminder(visitId: visitId)
    }
}

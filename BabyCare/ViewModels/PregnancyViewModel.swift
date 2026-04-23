import Foundation

/// 임신 모드 ViewModel.
/// Baby와 독립된 생명주기. FeatureFlag=false일 때도 VM은 항상 로드 가능 (테스트 용이성).
/// View에서 진입 지점 1곳에서만 FeatureFlag 분기 강제.
@MainActor @Observable
final class PregnancyViewModel {
    var activePregnancy: Pregnancy?
    var archivedPregnancies: [Pregnancy] = []
    var kickSessions: [KickSession] = []
    var prenatalVisits: [PrenatalVisit] = []
    var checklistItems: [PregnancyChecklistItem] = []
    var weightEntries: [PregnancyWeightEntry] = []
    var symptoms: [PregnancySymptom] = []

    /// 진행 중인 태동 세션 (UI가 실시간 갱신).
    var currentKickSession: KickSession?

    var isLoading = false
    var errorMessage: String?

    private let firestoreService: PregnancyFirestoreProviding

    init(firestoreService: PregnancyFirestoreProviding = FirestoreService.shared) {
        self.firestoreService = firestoreService
    }

    // MARK: - Data User Resolution

    /// 공유 임신 데이터 경로 분기. Baby 패턴과 동일.
    func dataUserId(currentUserId: String?) -> String? {
        activePregnancy?.ownerUserId ?? currentUserId
    }

    // MARK: - Load

    func loadActivePregnancy(userId: String) async {
        // UI 테스트 모드: UI_TESTING_WITH_PREGNANCY 플래그 시 mock 활성 임신 주입
        if CommandLine.arguments.contains("UI_TESTING") {
            if CommandLine.arguments.contains("UI_TESTING_WITH_PREGNANCY") {
                var mock = Pregnancy(
                    lmpDate: Calendar.current.date(byAdding: .day, value: -84, to: Date()),
                    dueDate: Calendar.current.date(byAdding: .day, value: 196, to: Date()),
                    fetusCount: 1,
                    babyNickname: "테스트아기"
                )
                mock.ownerUserId = userId
                self.activePregnancy = mock
            } else {
                self.activePregnancy = nil
            }
            isLoading = false
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            var p = try await firestoreService.fetchActivePregnancy(userId: userId)
            if p == nil {
                // 자신의 진행 중 임신이 없으면 파트너가 공유한 임신을 fallback으로 확인.
                p = try await firestoreService.fetchSharedPregnancy(currentUserId: userId)
            }
            if p?.ownerUserId == nil { p?.ownerUserId = userId }
            self.activePregnancy = p
            PregnancyWidgetSyncService.update(pregnancy: p)
            if let pid = p?.id, let dataOwner = p?.ownerUserId {
                async let kicks = firestoreService.fetchKickSessions(userId: dataOwner, pregnancyId: pid)
                async let visits = firestoreService.fetchPrenatalVisits(userId: dataOwner, pregnancyId: pid)
                async let items = firestoreService.fetchChecklistItems(userId: dataOwner, pregnancyId: pid)
                async let weights = firestoreService.fetchWeightEntries(userId: dataOwner, pregnancyId: pid)
                async let symptomList = firestoreService.fetchSymptoms(userId: dataOwner, pregnancyId: pid)
                self.kickSessions = (try? await kicks) ?? []
                self.prenatalVisits = (try? await visits) ?? []
                self.checklistItems = (try? await items) ?? []
                self.weightEntries = (try? await weights) ?? []
                self.symptoms = (try? await symptomList) ?? []
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadArchivedPregnancies(userId: String) async {
        do {
            archivedPregnancies = try await firestoreService.fetchArchivedPregnancies(userId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Create / Update

    func createPregnancy(lmpDate: Date?, dueDate: Date?, fetusCount: Int = 1,
                         babyNickname: String? = nil, userId: String) async {
        // 입력 validation — UI DatePicker로 1차 차단되지만 service-level 방어.
        if let validationError = Self.validateInputs(lmpDate: lmpDate, dueDate: dueDate, fetusCount: fetusCount) {
            errorMessage = validationError
            return
        }
        // 중복 활성 임신 방지
        if activePregnancy != nil {
            errorMessage = "이미 진행 중인 임신이 있습니다. 먼저 종료해주세요."
            return
        }
        // LMP 또는 dueDate 중 하나 필수. LMP만 있으면 dueDate = LMP + 280일.
        let computed = Self.computeEddIfNeeded(lmpDate: lmpDate, dueDate: dueDate)
        let pregnancy = Pregnancy(
            lmpDate: lmpDate,
            dueDate: computed.dueDate,
            eddHistory: computed.dueDate.map { [$0] },
            fetusCount: fetusCount,
            babyNickname: babyNickname
        )
        errorMessage = nil
        do {
            try await firestoreService.savePregnancy(pregnancy, userId: userId)
            await loadActivePregnancy(userId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 입력 검증 — 비정상 케이스 차단 (음수 임신 주차, 비현실 기간 등).
    /// 통과 시 nil, 실패 시 사용자 표시용 메시지 반환.
    static func validateInputs(lmpDate: Date?, dueDate: Date?, fetusCount: Int) -> String? {
        guard fetusCount >= 1 && fetusCount <= 5 else {
            return "태아 수는 1~5명 사이여야 합니다."
        }
        let now = Date()
        if let lmp = lmpDate, lmp > now {
            return "마지막 월경일은 오늘 이전이어야 합니다."
        }
        if let edd = dueDate {
            // EDD가 너무 과거 (출산 예정일이 이미 한참 지남)면 거부
            let cal = Calendar.current
            if let lower = cal.date(byAdding: .day, value: -90, to: now), edd < lower {
                return "예정일이 과거입니다. 출산이 완료되었다면 출산 전환을 사용하세요."
            }
            // EDD가 너무 미래
            if let upper = cal.date(byAdding: .day, value: 310, to: now), edd > upper {
                return "예정일이 너무 미래입니다."
            }
        }
        if let lmp = lmpDate, let edd = dueDate, edd <= lmp {
            return "예정일은 마지막 월경일 이후여야 합니다."
        }
        if lmpDate == nil && dueDate == nil {
            return "마지막 월경일 또는 예정일 중 하나는 필수입니다."
        }
        return nil
    }

    /// 긴급 복구용 — 활성 임신 데이터 완전 삭제 (하위 컬렉션 cascade).
    /// 실수로 생성된 pregnancy가 baby dashboard를 덮어쓰는 상황 등 escape hatch.
    /// 사용 후 PregnancyWidget clear + activePregnancy nil 반영.
    func deleteActivePregnancy(userId: String) async {
        guard let p = activePregnancy else { return }
        do {
            try await firestoreService.deletePregnancy(p.id, userId: userId)
            activePregnancy = nil
            kickSessions = []
            prenatalVisits = []
            checklistItems = []
            weightEntries = []
            PregnancyWidgetSyncService.update(pregnancy: nil)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// EDD 변경 시 이력 보존 (append-only).
    func updateEDD(newDueDate: Date, userId: String) async {
        guard var p = activePregnancy else { return }
        var history = p.eddHistory ?? []
        if let existing = p.dueDate, !history.contains(existing) {
            history.append(existing)
        }
        p.dueDate = newDueDate
        p.eddHistory = history
        p.updatedAt = Date()
        do {
            try await firestoreService.savePregnancy(p, userId: userId)
            self.activePregnancy = p
            PregnancyWidgetSyncService.update(pregnancy: p)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Week / D-day

    var currentWeekAndDay: (weeks: Int, days: Int)? {
        activePregnancy?.currentWeekAndDay
    }

    var dDay: Int? {
        activePregnancy?.dDay
    }

    // MARK: - Kick Session

    func startKickSession(userId: String) async {
        guard let pid = activePregnancy?.id else { return }
        let session = KickSession(pregnancyId: pid)
        currentKickSession = session
        do {
            try await firestoreService.saveKickSession(session, userId: userId, pregnancyId: pid)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func recordKick(userId: String) async {
        guard var session = currentKickSession, let pid = activePregnancy?.id else { return }
        session.kicks.append(KickEvent())
        // ACOG 2시간 초과 시 자동 종료.
        if session.exceededTwoHours {
            session.endedAt = session.startedAt.addingTimeInterval(7200)
            currentKickSession = nil
        } else {
            currentKickSession = session
        }
        do {
            try await firestoreService.saveKickSession(session, userId: userId, pregnancyId: pid)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func endKickSession(userId: String) async {
        guard var session = currentKickSession, let pid = activePregnancy?.id else { return }
        session.endedAt = Date()
        currentKickSession = nil
        do {
            try await firestoreService.saveKickSession(session, userId: userId, pregnancyId: pid)
            kickSessions = try await firestoreService.fetchKickSessions(userId: userId, pregnancyId: pid)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Checklist

    func toggleChecklistItem(_ item: PregnancyChecklistItem, userId: String) async {
        guard let pid = activePregnancy?.id else { return }
        var updated = item
        updated.isCompleted.toggle()
        updated.completedAt = updated.isCompleted ? Date() : nil
        do {
            try await firestoreService.saveChecklistItem(updated, userId: userId, pregnancyId: pid)
            if let idx = checklistItems.firstIndex(where: { $0.id == updated.id }) {
                checklistItems[idx] = updated
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 사용자 추가 체크리스트 항목 (source=user).
    func addChecklistItem(title: String, category: String = "custom", userId: String) async {
        guard let pid = activePregnancy?.id else { return }
        let newItem = PregnancyChecklistItem(
            pregnancyId: pid,
            title: title,
            category: category,
            source: "user",
            order: checklistItems.count
        )
        do {
            try await firestoreService.saveChecklistItem(newItem, userId: userId, pregnancyId: pid)
            checklistItems.append(newItem)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 번들 템플릿 로드 후 Firestore에 저장 (최초 1회).
    func loadBundleChecklistIfNeeded(userId: String) async {
        guard let pid = activePregnancy?.id else { return }
        // 이미 bundle 항목이 있으면 스킵.
        let hasBundleItems = checklistItems.contains { $0.source == "bundle" }
        guard !hasBundleItems else { return }

        guard let url = Bundle.main.url(forResource: "prenatal-checklist", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return }

        struct BundleItem: Codable {
            let id: String
            let title: String
            let category: String
            let targetWeek: Int?
            let source: String
            let order: Int?
        }

        guard let bundleItems = try? JSONDecoder().decode([BundleItem].self, from: data) else { return }
        for b in bundleItems {
            let item = PregnancyChecklistItem(
                id: b.id,
                pregnancyId: pid,
                title: b.title,
                category: b.category,
                targetWeek: b.targetWeek,
                source: b.source,
                order: b.order
            )
            do {
                try await firestoreService.saveChecklistItem(item, userId: userId, pregnancyId: pid)
                checklistItems.append(item)
            } catch {
                // 부분 실패 허용 — 다음 항목 계속 진행
            }
        }
    }

    // MARK: - Prenatal Visit

    func savePrenatalVisit(_ visit: PrenatalVisit, userId: String) async {
        guard let pid = activePregnancy?.id else { return }
        do {
            try await firestoreService.savePrenatalVisit(visit, userId: userId, pregnancyId: pid)
            if let idx = prenatalVisits.firstIndex(where: { $0.id == visit.id }) {
                prenatalVisits[idx] = visit
            } else {
                prenatalVisits.append(visit)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func togglePrenatalVisit(_ visit: PrenatalVisit, userId: String) async {
        var updated = visit
        updated.isCompleted.toggle()
        updated.visitedAt = updated.isCompleted ? Date() : nil
        updated.updatedAt = Date()
        await savePrenatalVisit(updated, userId: userId)
    }

    // MARK: - Weight Entry

    func addWeightEntry(_ entry: PregnancyWeightEntry, userId: String) async {
        guard let pid = activePregnancy?.id else { return }
        do {
            try await firestoreService.saveWeightEntry(entry, userId: userId, pregnancyId: pid)
            weightEntries.append(entry)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Symptom

    func addSymptom(_ symptom: PregnancySymptom, userId: String) async {
        guard let pid = activePregnancy?.id else { return }
        do {
            try await firestoreService.saveSymptom(symptom, userId: userId, pregnancyId: pid)
            symptoms.insert(symptom, at: 0)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Transition

    /// Pregnancy → Baby 전환. WriteBatch 원자성 보장.
    func transitionToBaby(babyName: String, gender: Baby.Gender, birthDate: Date,
                          userId: String) async throws -> Baby {
        guard let p = activePregnancy else {
            throw PregnancyError.noActivePregnancy
        }
        // 전환 중 마커 (실패 복구용).
        try await firestoreService.markTransitionPending(p.id, userId: userId)

        let newBaby = Baby(
            name: babyName.isEmpty ? (p.babyNickname ?? "우리 아기") : babyName,
            birthDate: birthDate,
            gender: gender
        )
        try await firestoreService.transitionPregnancyToBaby(
            pregnancy: p,
            newBaby: newBaby,
            userId: userId
        )
        // 로컬 상태 업데이트 + 위젯 clear
        activePregnancy = nil
        PregnancyWidgetSyncService.clear()
        return newBaby
    }

    // MARK: - Partner Sharing

    func addPartner(email: String, userId: String) async throws {
        guard let pid = activePregnancy?.id else {
            throw PregnancyError.noActivePregnancy
        }
        try await firestoreService.addPregnancyPartner(email: email, userId: userId, pregnancyId: pid)
        await loadActivePregnancy(userId: userId)
    }

    func removePartner(uid: String, userId: String) async throws {
        guard let pid = activePregnancy?.id else {
            throw PregnancyError.noActivePregnancy
        }
        try await firestoreService.removePregnancyPartner(partnerUid: uid, userId: userId, pregnancyId: pid)
        await loadActivePregnancy(userId: userId)
    }

    // MARK: - Helpers

    private static func computeEddIfNeeded(lmpDate: Date?, dueDate: Date?) -> (dueDate: Date?, lmp: Date?) {
        if let due = dueDate { return (due, lmpDate) }
        if let lmp = lmpDate {
            let computed = Calendar.current.date(byAdding: .day, value: 280, to: lmp)
            return (computed, lmp)
        }
        return (nil, nil)
    }

    enum PregnancyError: LocalizedError {
        case noActivePregnancy

        var errorDescription: String? {
            switch self {
            case .noActivePregnancy: return "활성 임신 기록이 없습니다."
            }
        }
    }
}

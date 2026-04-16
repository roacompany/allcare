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

    /// 진행 중인 태동 세션 (UI가 실시간 갱신).
    var currentKickSession: KickSession?

    var isLoading = false
    var errorMessage: String?

    private let firestoreService = FirestoreService.shared

    // MARK: - Data User Resolution

    /// 공유 임신 데이터 경로 분기. Baby 패턴과 동일.
    func dataUserId(currentUserId: String?) -> String? {
        activePregnancy?.ownerUserId ?? currentUserId
    }

    // MARK: - Load

    func loadActivePregnancy(userId: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            var p = try await firestoreService.fetchActivePregnancy(userId: userId)
            p?.ownerUserId = userId
            self.activePregnancy = p
            PregnancyWidgetSyncService.update(pregnancy: p)
            if let pid = p?.id {
                async let kicks = firestoreService.fetchKickSessions(userId: userId, pregnancyId: pid)
                async let visits = firestoreService.fetchPrenatalVisits(userId: userId, pregnancyId: pid)
                async let items = firestoreService.fetchChecklistItems(userId: userId, pregnancyId: pid)
                async let weights = firestoreService.fetchWeightEntries(userId: userId, pregnancyId: pid)
                self.kickSessions = (try? await kicks) ?? []
                self.prenatalVisits = (try? await visits) ?? []
                self.checklistItems = (try? await items) ?? []
                self.weightEntries = (try? await weights) ?? []
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
        // LMP 또는 dueDate 중 하나 필수. LMP만 있으면 dueDate = LMP + 280일.
        let computed = Self.computeEddIfNeeded(lmpDate: lmpDate, dueDate: dueDate)
        let pregnancy = Pregnancy(
            lmpDate: lmpDate,
            dueDate: computed.dueDate,
            eddHistory: computed.dueDate.map { [$0] },
            fetusCount: fetusCount,
            babyNickname: babyNickname
        )
        do {
            try await firestoreService.savePregnancy(pregnancy, userId: userId)
            await loadActivePregnancy(userId: userId)
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
        // 로컬 상태 업데이트
        activePregnancy = nil
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

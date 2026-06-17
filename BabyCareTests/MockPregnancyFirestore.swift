import Foundation
@testable import BabyCare

/// PregnancyViewModel 통합 테스트용 Mock. 호출 기록 + 커스텀 리턴 값 스텁 지원.
///
/// 실제 Firestore 통신 없이 PregnancyViewModel 플로우 검증.
/// Swift 6 Sendable: 단일 쓰레드 테스트 전용이므로 `@unchecked Sendable`.
final class MockPregnancyFirestore: PregnancyFirestoreProviding, @unchecked Sendable {
    // MARK: - 스텁

    var activePregnancyResponse: Pregnancy?
    var archivedPregnanciesResponse: [Pregnancy] = []
    var sharedPregnancyResponse: Pregnancy?
    var kickSessionsResponse: [KickSession] = []
    var prenatalVisitsResponse: [PrenatalVisit] = []
    var checklistItemsResponse: [PregnancyChecklistItem] = []
    var weightEntriesResponse: [PregnancyWeightEntry] = []
    var symptomsResponse: [PregnancySymptom] = []
    var vitalEntriesResponse: [PregnancyVitalEntry] = []
    var contractionSessionsResponse: [ContractionSession] = []

    // MARK: - 에러 주입

    var errorOnFetchActivePregnancy: Error?
    var errorOnSavePregnancy: Error?
    var errorOnTransition: Error?
    var errorOnFetchSharedPregnancy: Error?

    // MARK: - 에러 주입 (rollback)

    var errorOnRollbackTransitionPending: Error?

    // MARK: - 호출 기록

    private(set) var savePregnancyCalls: [Pregnancy] = []
    private(set) var fetchActivePregnancyCalls: [String] = []
    private(set) var fetchSharedPregnancyCalls: [String] = []
    private(set) var deletePregnancyCalls: [String] = []
    private(set) var transitionCalls: [(pregnancyId: String, babyName: String)] = []
    /// 멱등 시뮬: 이미 생성된 것으로 간주할 Baby.id (크래시 후 잔존 상태 재현).
    var existingBabyIds: Set<String> = []
    /// 실제로 새로 생성된 Baby.id (중복 생성 여부 검증용).
    private(set) var createdBabyIds: [String] = []
    private(set) var terminateCalls: [(pregnancyId: String, outcome: PregnancyOutcome)] = []
    private(set) var markTransitionPendingCalls: [String] = []
    private(set) var rollbackTransitionPendingCalls: [String] = []
    private(set) var saveKickSessionCalls: [KickSession] = []
    private(set) var saveKickSessionUserIds: [String] = []
    private(set) var savePrenatalVisitCalls: [PrenatalVisit] = []
    private(set) var savePrenatalVisitUserIds: [String] = []
    private(set) var saveChecklistItemCalls: [PregnancyChecklistItem] = []
    private(set) var saveChecklistItemUserIds: [String] = []
    private(set) var saveWeightEntryCalls: [PregnancyWeightEntry] = []
    private(set) var saveWeightEntryUserIds: [String] = []
    private(set) var saveSymptomCalls: [PregnancySymptom] = []
    private(set) var saveSymptomUserIds: [String] = []
    private(set) var saveVitalEntryCalls: [PregnancyVitalEntry] = []
    private(set) var saveVitalEntryUserIds: [String] = []
    private(set) var saveContractionSessionCalls: [ContractionSession] = []

    // MARK: - Protocol Conformance

    func savePregnancy(_ pregnancy: Pregnancy, userId: String) async throws {
        if let err = errorOnSavePregnancy { throw err }
        savePregnancyCalls.append(pregnancy)
    }

    func fetchActivePregnancy(userId: String) async throws -> Pregnancy? {
        fetchActivePregnancyCalls.append(userId)
        if let err = errorOnFetchActivePregnancy { throw err }
        return activePregnancyResponse
    }

    func fetchArchivedPregnancies(userId: String) async throws -> [Pregnancy] {
        archivedPregnanciesResponse
    }

    func deletePregnancy(_ pregnancyId: String, userId: String) async throws {
        deletePregnancyCalls.append(pregnancyId)
    }

    func transitionPregnancyToBaby(pregnancy: Pregnancy, newBaby: Baby, userId: String) async throws {
        if let err = errorOnTransition { throw err }
        transitionCalls.append((pregnancy.id, newBaby.name))
        guard !existingBabyIds.contains(newBaby.id) else { return }  // 멱등: 이미 존재하면 no-op
        existingBabyIds.insert(newBaby.id)
        createdBabyIds.append(newBaby.id)
    }

    func terminatePregnancy(pregnancy: Pregnancy, outcome: PregnancyOutcome, userId: String) async throws {
        if let err = errorOnTransition { throw err }
        terminateCalls.append((pregnancy.id, outcome))
    }

    func markTransitionPending(_ pregnancyId: String, userId: String) async throws {
        markTransitionPendingCalls.append(pregnancyId)
    }

    func saveKickSession(_ session: KickSession, userId: String, pregnancyId: String) async throws {
        saveKickSessionCalls.append(session)
        saveKickSessionUserIds.append(userId)
    }

    func fetchKickSessions(userId: String, pregnancyId: String, limit: Int) async throws -> [KickSession] {
        kickSessionsResponse
    }

    func savePrenatalVisit(_ visit: PrenatalVisit, userId: String, pregnancyId: String) async throws {
        savePrenatalVisitCalls.append(visit)
        savePrenatalVisitUserIds.append(userId)
    }

    func fetchPrenatalVisits(userId: String, pregnancyId: String) async throws -> [PrenatalVisit] {
        prenatalVisitsResponse
    }

    func saveChecklistItem(_ item: PregnancyChecklistItem, userId: String, pregnancyId: String) async throws {
        saveChecklistItemCalls.append(item)
        saveChecklistItemUserIds.append(userId)
    }

    func fetchChecklistItems(userId: String, pregnancyId: String) async throws -> [PregnancyChecklistItem] {
        checklistItemsResponse
    }

    func saveWeightEntry(_ entry: PregnancyWeightEntry, userId: String, pregnancyId: String) async throws {
        saveWeightEntryCalls.append(entry)
        saveWeightEntryUserIds.append(userId)
    }

    func fetchWeightEntries(userId: String, pregnancyId: String) async throws -> [PregnancyWeightEntry] {
        weightEntriesResponse
    }

    func saveSymptom(_ symptom: PregnancySymptom, userId: String, pregnancyId: String) async throws {
        saveSymptomCalls.append(symptom)
        saveSymptomUserIds.append(userId)
    }

    func fetchSymptoms(userId: String, pregnancyId: String) async throws -> [PregnancySymptom] {
        symptomsResponse
    }

    func saveVitalEntry(_ entry: PregnancyVitalEntry, userId: String, pregnancyId: String) async throws {
        saveVitalEntryCalls.append(entry)
        saveVitalEntryUserIds.append(userId)
    }

    func fetchVitalEntries(userId: String, pregnancyId: String) async throws -> [PregnancyVitalEntry] {
        vitalEntriesResponse
    }

    func saveContractionSession(_ session: ContractionSession, userId: String, pregnancyId: String) async throws {
        saveContractionSessionCalls.append(session)
    }

    func fetchContractionSessions(userId: String, pregnancyId: String) async throws -> [ContractionSession] {
        contractionSessionsResponse
    }

    func addPregnancyPartner(email: String, userId: String, pregnancyId: String) async throws {}

    func removePregnancyPartner(partnerUid: String, userId: String, pregnancyId: String) async throws {}

    func rollbackTransitionPending(_ pregnancyId: String, userId: String) async throws {
        if let err = errorOnRollbackTransitionPending { throw err }
        rollbackTransitionPendingCalls.append(pregnancyId)
    }

    func fetchSharedPregnancy(currentUserId: String) async throws -> Pregnancy? {
        fetchSharedPregnancyCalls.append(currentUserId)
        if let err = errorOnFetchSharedPregnancy { throw err }
        return sharedPregnancyResponse
    }
}

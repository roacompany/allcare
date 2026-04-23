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

    // MARK: - 에러 주입

    var errorOnFetchActivePregnancy: Error?
    var errorOnSavePregnancy: Error?
    var errorOnTransition: Error?
    var errorOnFetchSharedPregnancy: Error?

    // MARK: - 호출 기록

    private(set) var savePregnancyCalls: [Pregnancy] = []
    private(set) var fetchActivePregnancyCalls: [String] = []
    private(set) var fetchSharedPregnancyCalls: [String] = []
    private(set) var deletePregnancyCalls: [String] = []
    private(set) var transitionCalls: [(pregnancyId: String, babyName: String)] = []
    private(set) var markTransitionPendingCalls: [String] = []
    private(set) var saveKickSessionCalls: [KickSession] = []
    private(set) var savePrenatalVisitCalls: [PrenatalVisit] = []
    private(set) var saveChecklistItemCalls: [PregnancyChecklistItem] = []
    private(set) var saveWeightEntryCalls: [PregnancyWeightEntry] = []
    private(set) var saveSymptomCalls: [PregnancySymptom] = []

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
    }

    func markTransitionPending(_ pregnancyId: String, userId: String) async throws {
        markTransitionPendingCalls.append(pregnancyId)
    }

    func saveKickSession(_ session: KickSession, userId: String, pregnancyId: String) async throws {
        saveKickSessionCalls.append(session)
    }

    func fetchKickSessions(userId: String, pregnancyId: String, limit: Int) async throws -> [KickSession] {
        kickSessionsResponse
    }

    func savePrenatalVisit(_ visit: PrenatalVisit, userId: String, pregnancyId: String) async throws {
        savePrenatalVisitCalls.append(visit)
    }

    func fetchPrenatalVisits(userId: String, pregnancyId: String) async throws -> [PrenatalVisit] {
        prenatalVisitsResponse
    }

    func saveChecklistItem(_ item: PregnancyChecklistItem, userId: String, pregnancyId: String) async throws {
        saveChecklistItemCalls.append(item)
    }

    func fetchChecklistItems(userId: String, pregnancyId: String) async throws -> [PregnancyChecklistItem] {
        checklistItemsResponse
    }

    func saveWeightEntry(_ entry: PregnancyWeightEntry, userId: String, pregnancyId: String) async throws {
        saveWeightEntryCalls.append(entry)
    }

    func fetchWeightEntries(userId: String, pregnancyId: String) async throws -> [PregnancyWeightEntry] {
        weightEntriesResponse
    }

    func saveSymptom(_ symptom: PregnancySymptom, userId: String, pregnancyId: String) async throws {
        saveSymptomCalls.append(symptom)
    }

    func fetchSymptoms(userId: String, pregnancyId: String) async throws -> [PregnancySymptom] {
        symptomsResponse
    }

    func addPregnancyPartner(email: String, userId: String, pregnancyId: String) async throws {}

    func removePregnancyPartner(partnerUid: String, userId: String, pregnancyId: String) async throws {}

    func fetchSharedPregnancy(currentUserId: String) async throws -> Pregnancy? {
        fetchSharedPregnancyCalls.append(currentUserId)
        if let err = errorOnFetchSharedPregnancy { throw err }
        return sharedPregnancyResponse
    }
}

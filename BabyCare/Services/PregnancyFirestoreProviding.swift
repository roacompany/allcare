import Foundation

/// PregnancyViewModel이 의존하는 Firestore 작업만 추출한 narrow protocol (ISP).
///
/// FirestoreService 전체를 추상화하는 대신, 임신 시스템에 필요한 메서드만
/// 노출해 통합 테스트에서 Mock 주입 가능. 신규 임신 로직 추가 시 필요한 메서드를
/// 이 protocol에 추가.
protocol PregnancyFirestoreProviding: Sendable {
    func savePregnancy(_ pregnancy: Pregnancy, userId: String) async throws
    func fetchActivePregnancy(userId: String) async throws -> Pregnancy?
    func fetchArchivedPregnancies(userId: String) async throws -> [Pregnancy]
    func deletePregnancy(_ pregnancyId: String, userId: String) async throws
    func transitionPregnancyToBaby(pregnancy: Pregnancy, newBaby: Baby, userId: String) async throws
    func terminatePregnancy(pregnancy: Pregnancy, outcome: PregnancyOutcome, userId: String) async throws
    func markTransitionPending(_ pregnancyId: String, userId: String) async throws
    func saveKickSession(_ session: KickSession, userId: String, pregnancyId: String) async throws
    func fetchKickSessions(userId: String, pregnancyId: String, limit: Int) async throws -> [KickSession]
    func savePrenatalVisit(_ visit: PrenatalVisit, userId: String, pregnancyId: String) async throws
    func fetchPrenatalVisits(userId: String, pregnancyId: String) async throws -> [PrenatalVisit]
    func saveChecklistItem(_ item: PregnancyChecklistItem, userId: String, pregnancyId: String) async throws
    func fetchChecklistItems(userId: String, pregnancyId: String) async throws -> [PregnancyChecklistItem]
    func saveWeightEntry(_ entry: PregnancyWeightEntry, userId: String, pregnancyId: String) async throws
    func fetchWeightEntries(userId: String, pregnancyId: String) async throws -> [PregnancyWeightEntry]
    func saveSymptom(_ symptom: PregnancySymptom, userId: String, pregnancyId: String) async throws
    func fetchSymptoms(userId: String, pregnancyId: String) async throws -> [PregnancySymptom]
    func addPregnancyPartner(email: String, userId: String, pregnancyId: String) async throws
    func removePregnancyPartner(partnerUid: String, userId: String, pregnancyId: String) async throws
    /// 파트너가 sharedWith에 포함된 진행 중 임신 조회 (collectionGroup 쿼리).
    func fetchSharedPregnancy(currentUserId: String) async throws -> Pregnancy?
    /// pending 전환을 취소: transitionState 제거 + ongoing 복원. 문서 삭제 금지.
    func rollbackTransitionPending(_ pregnancyId: String, userId: String) async throws
}

extension PregnancyFirestoreProviding {
    /// limit 생략 시 기본값 30 제공 (프로토콜 default 미지원 workaround).
    func fetchKickSessions(userId: String, pregnancyId: String) async throws -> [KickSession] {
        try await fetchKickSessions(userId: userId, pregnancyId: pregnancyId, limit: 30)
    }
}

extension FirestoreService: PregnancyFirestoreProviding {}

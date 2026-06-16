import Foundation

/// 진료 준비 질문 — 다음 검진에서 물어볼 것을 적어두는 체크 가능한 메모.
///
/// 별도 Firestore 컬렉션을 만들지 않고 `PrenatalVisit.preparationQuestions` 로 임베딩한다(질문은 검진에 종속).
/// 검진과 함께 소유자 path(`dataUserId`)로 저장되므로 공유 격리(#41)를 자동 준수한다.
struct VisitPrepQuestion: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var text: String
    /// "물어봤어요" 토글 — 검진 때 확인한 질문 소거용.
    var asked: Bool = false
}

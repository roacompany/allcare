import Foundation

/// 진료 준비 질문(PrenatalVisit.preparationQuestions 임베딩) 글루 — 본체 VM 비대화 방지용 분리.
/// 저장은 모두 본체 `savePrenatalVisit`(소유자 path) 경유 → 공유 격리(#41) 자동 준수.
extension PregnancyViewModel {

    /// 진료 준비 질문 추가(다음 검진에 임베딩 저장).
    func addVisitQuestion(to visit: PrenatalVisit, text: String, userId: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var updated = visit
        var questions = updated.preparationQuestions ?? []
        questions.append(VisitPrepQuestion(text: trimmed))
        updated.preparationQuestions = questions
        updated.updatedAt = Date()
        await savePrenatalVisit(updated, userId: userId)
    }

    /// 질문 "물어봤어요" 토글.
    func toggleVisitQuestion(in visit: PrenatalVisit, questionId: String, userId: String) async {
        guard var questions = visit.preparationQuestions,
              let idx = questions.firstIndex(where: { $0.id == questionId }) else { return }
        questions[idx].asked.toggle()
        var updated = visit
        updated.preparationQuestions = questions
        updated.updatedAt = Date()
        await savePrenatalVisit(updated, userId: userId)
    }

    /// 질문 삭제.
    func deleteVisitQuestion(in visit: PrenatalVisit, questionId: String, userId: String) async {
        guard var questions = visit.preparationQuestions,
              questions.contains(where: { $0.id == questionId }) else { return }
        questions.removeAll { $0.id == questionId }
        var updated = visit
        updated.preparationQuestions = questions
        updated.updatedAt = Date()
        await savePrenatalVisit(updated, userId: userId)
    }
}

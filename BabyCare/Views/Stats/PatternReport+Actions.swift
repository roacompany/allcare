import SwiftUI
import Charts

extension PatternReportView {
    // MARK: - Actions

    func loadReport() async {
        guard let userId = authVM.currentUserId,
              let babyId = babyVM.selectedBaby?.id else { return }
        await vm.loadReport(userId: userId, babyId: babyId)
    }

    func requestAI() async {
        guard let baby = babyVM.selectedBaby else { return }
        await vm.requestAIInsight(
            babyName: baby.name,
            babyAge: baby.ageText,
            gender: baby.gender.displayName
        )
    }
}

import SwiftUI
import Charts

extension PatternReportView {
    // MARK: - Actions

    func loadReport() async {
        guard let currentUserId = authVM.currentUserId,
              let babyId = babyVM.selectedBaby?.id else { return }
        let dataUserId = babyVM.dataUserId(currentUserId: currentUserId) ?? currentUserId
        await vm.loadReport(userId: dataUserId, babyId: babyId)
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

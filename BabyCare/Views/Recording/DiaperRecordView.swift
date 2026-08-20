import SwiftUI

// MARK: - DiaperRecordView
// Diaper type selection with one-tap quick save.

struct DiaperRecordView: View {
    @Environment(ActivityViewModel.self) private var activityVM
    @Environment(BabyViewModel.self) private var babyVM
    @Environment(AuthViewModel.self) private var authVM
    @Environment(ProductViewModel.self) private var productVM

    var onSaved: (() -> Void)? = nil

    @State private var selectedDiaperType: Activity.ActivityType = .diaperWet
    @State private var isSaving = false
    @State private var productCandidates: [BabyProduct] = []

    // 액센트 = 선택한 타입의 강조색 (소변=앰버 · 대변/소변+대변=브라운) — 홈 정본과 같은 색 언어 (2026-08-20 재작업).
    private var accentColor: Color { Color(selectedDiaperType.emphasisColor) }

    // 아이콘 = Activity 단일 소스(type.icon) — 잎사귀 등 폼 자체 아이콘 제거, 홈 타일·타임라인과 일치.
    private let diaperTypes: [Activity.ActivityType] = [.diaperWet, .diaperDirty, .diaperBoth]

    var body: some View {
        @Bindable var vm = activityVM

        ScrollView {
            VStack(spacing: 24) {
                // Header 제거 — 내비 제목 + 기저귀 탭이 이미 같은 정보 (3중 제목 해소, 2026-08-20 재작업)

                // ── Time adjustment ───────────────────────────────────────
                TimeAdjustmentSection(accentColor: accentColor)

                // ── Type cards ─────────────────────────────────────────────
                VStack(spacing: 12) {
                    ForEach(diaperTypes, id: \.self) { type in
                        DiaperTypeCard(
                            label: type.displayName,
                            icon: type.icon,
                            isSelected: selectedDiaperType == type,
                            color: cardColor(for: type),
                            showsBothBadge: type == .diaperBoth
                        ) {
                            withAnimation(.spring(duration: 0.25)) {
                                selectedDiaperType = type
                            }
                        }
                    }
                }
                .padding(.horizontal)

                // ── Stool details (대변/소변+대변 시에만 표시) ────────────
                if selectedDiaperType == .diaperDirty || selectedDiaperType == .diaperBoth {
                    StoolDetailSection(accentColor: cardColor(for: .diaperDirty))
                        .padding(.horizontal)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                // ── Note ───────────────────────────────────────────────────
                NoteField(note: $vm.note, accentColor: accentColor)
                    .padding(.horizontal)
                    .padding(.bottom, 12)
            }
            .padding(.top, 8)
        }
        .safeAreaInset(edge: .bottom) {
            SaveBar(isSaving: isSaving, color: accentColor, action: quickSave)
        }
        .onAppear {
            AnalyticsService.shared.trackScreen(AnalyticsScreens.diaperRecording)
        }
        .sheet(isPresented: Binding(
            get: { !productCandidates.isEmpty },
            set: { if !$0 { productCandidates = [] } }
        )) {
            ProductPickerSheet(products: productCandidates) { selected in
                Task {
                    guard let userId = authVM.currentUserId else { return }
                    await productVM.deductFromProduct(selected, userId: userId)
                }
                productCandidates = []
                isSaving = false
                onSaved?()
            }
            .presentationDetents([.medium])
        }
    }

    // MARK: - Actions

    private func quickSave() {
        guard let currentUserId = authVM.currentUserId,
              let baby = babyVM.selectedBaby else { return }
        let dataUserId = babyVM.dataUserId(currentUserId: currentUserId) ?? currentUserId
        isSaving = true
        Task {
            await activityVM.saveActivity(
                userId: dataUserId,
                currentUserId: currentUserId,
                babyId: baby.id,
                type: selectedDiaperType
            )
            guard activityVM.errorMessage == nil else {
                isSaving = false
                return
            }
            // 저장 성공 후 발화. category = 영어 rawValue (diaper_wet/diaper_dirty/diaper_both)
            AnalyticsService.shared.trackEvent(AnalyticsEvents.diaperRecordSave, parameters: [AnalyticsParams.category: selectedDiaperType.rawValue])
            if let candidates = await productVM.deductStockForActivity(selectedDiaperType, userId: currentUserId) {
                productCandidates = candidates
            } else {
                isSaving = false
                onSaved?()
            }
        }
    }

    // 카드 색 = Activity 단일 소스(emphasisColor) — 소변=앰버, 대변/소변+대변=브라운 (홈 정본과 일치).
    private func cardColor(for type: Activity.ActivityType) -> Color {
        Color(type.emphasisColor)
    }
}

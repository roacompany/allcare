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

    private let accentColor = AppColors.sageColor

    private let diaperTypes: [(Activity.ActivityType, String, String)] = [
        (.diaperWet,   "소변",       "drop.fill"),
        (.diaperDirty, "대변",       "leaf.fill"),
        (.diaperBoth,  "소변+대변",  "humidity.fill"),
    ]

    var body: some View {
        @Bindable var vm = activityVM

        ScrollView {
            VStack(spacing: 24) {

                // ── Header ─────────────────────────────────────────────────
                HStack(spacing: 10) {
                    Image(systemName: "humidity.fill")
                        .font(.title2)
                        .foregroundStyle(accentColor)
                    Text("기저귀")
                        .font(.title3.bold())
                    Spacer()
                }
                .padding(.horizontal)

                // ── Time adjustment ───────────────────────────────────────
                TimeAdjustmentSection(accentColor: accentColor)

                // ── Type cards ─────────────────────────────────────────────
                VStack(spacing: 12) {
                    ForEach(diaperTypes, id: \.0) { (type, label, icon) in
                        DiaperTypeCard(
                            label: label,
                            icon: icon,
                            isSelected: selectedDiaperType == type,
                            color: cardColor(for: type)
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

                // ── Quick save ─────────────────────────────────────────────
                Button(action: quickSave) {
                    HStack(spacing: 10) {
                        if isSaving {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title3)
                            Text("바로 저장")
                                .font(.headline)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: accentColor.opacity(0.35), radius: 8, y: 4)
                }
                .disabled(isSaving)
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
            .padding(.top, 8)
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
        AnalyticsService.shared.trackEvent(AnalyticsEvents.diaperRecordSave, parameters: [AnalyticsParams.category: selectedDiaperType.displayName])
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
            if let candidates = await productVM.deductStockForActivity(selectedDiaperType, userId: currentUserId) {
                productCandidates = candidates
            } else {
                isSaving = false
                onSaved?()
            }
        }
    }

    private func cardColor(for type: Activity.ActivityType) -> Color {
        switch type {
        case .diaperWet:   AppColors.sageColor
        case .diaperDirty: AppColors.warmOrangeColor
        default:           AppColors.softPurpleColor
        }
    }
}

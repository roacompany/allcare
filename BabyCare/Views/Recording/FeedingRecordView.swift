import SwiftUI

// MARK: - FeedingRecordView
// Handles both breast and bottle (and solid / snack) feeding records.

struct FeedingRecordView: View {
    @Environment(ActivityViewModel.self) private var activityVM
    @Environment(BabyViewModel.self) private var babyVM
    @Environment(AuthViewModel.self) private var authVM
    @Environment(ProductViewModel.self) private var productVM

    let type: Activity.ActivityType
    var onSaved: (() -> Void)? = nil

    @State private var isSaving = false
    @State private var productCandidates: [BabyProduct] = []

    // Save is allowed unless bottle feeding with no amount entered
    private var canSave: Bool {
        if type == .feedingBottle {
            return (Int(activityVM.amount) ?? 0) > 0
        }
        return true
    }

    // Accent colour per sub-type
    private var accentColor: Color {
        switch type {
        case .feedingBreast:  .pink
        case .feedingBottle:  AppColors.indigoColor
        case .feedingSolid:   AppColors.warmOrangeColor
        case .feedingSnack:   AppColors.sageColor
        default:              .pink
        }
    }

    var body: some View {
        @Bindable var vm = activityVM

        ScrollView {

            VStack(spacing: 20) {
                typeHeader
                TimeAdjustmentSection(
                    accentColor: accentColor,
                    showEndTime: type.needsTimer
                )
                timerSection
                breastSideSection
                foodSections
                bottleAmountSection(vm: vm)

                NoteField(note: $vm.note, accentColor: accentColor)
                    .padding(.horizontal)

                SaveButton(isSaving: isSaving, isEnabled: canSave, color: accentColor, action: save)
                    .padding(.horizontal)
                    .padding(.bottom, 16)
            }
            .padding(.top, 8)
        }
        .onAppear {
            // 모유수유: 이전 기록의 반대편 자동 제안
            if type == .feedingBreast {
                if let lastSide = activityVM.lastFeeding?.side {
                    switch lastSide {
                    case .left:  activityVM.selectedSide = .right
                    case .right: activityVM.selectedSide = .left
                    case .both:  break
                    }
                }
            }
        }
        .sheet(isPresented: Binding(
            get: { !productCandidates.isEmpty },
            set: { if !$0 { productCandidates = [] } }
        )) {
            ProductPickerSheet(products: productCandidates) { selected in
                Task {
                    guard let userId = authVM.currentUserId else { return }
                    let feedAmount = Int(activityVM.amount)
                    await productVM.deductFromProduct(selected, userId: userId, recordedAmount: feedAmount)
                }
                productCandidates = []
                isSaving = false
                onSaved?()
            }
            .presentationDetents([.medium])
        }
    }

    // MARK: - Body Sections

    private var typeHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: type.icon)
                .font(.title2)
                .foregroundStyle(accentColor)
            Text(type.displayName)
                .font(.title3.bold())
                .foregroundStyle(.primary)
            Spacer()
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private var timerSection: some View {
        if type.needsTimer {
            TimerView(type: type, accentColor: accentColor)
                .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private var breastSideSection: some View {
        if type == .feedingBreast {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("수유 방향", systemImage: "arrow.left.arrow.right")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)
                    Spacer()
                    if let lastSide = activityVM.lastFeeding?.side, lastSide != .both {
                        Text("이전: \(lastSide == .left ? "왼쪽" : "오른쪽")")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }

                HStack(spacing: 12) {
                    ForEach(Activity.BreastSide.allCases, id: \.self) { side in
                        SideButton(
                            side: side,
                            isSelected: activityVM.selectedSide == side,
                            color: accentColor
                        ) {
                            activityVM.selectedSide = side
                        }
                    }
                }
            }
            .padding()
            .background(accentColor.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private var foodSections: some View {
        if type == .feedingSolid {
            SolidFoodSection(accentColor: accentColor)
                .padding(.horizontal)
        }
        if type == .feedingSnack {
            SnackSection(accentColor: accentColor)
                .padding(.horizontal)
        }
    }

    @ViewBuilder
    private func bottleAmountSection(vm: ActivityViewModel) -> some View {
        if type == .feedingBottle {
            VStack(alignment: .leading, spacing: 10) {
                Label("섭취량 (ml)", systemImage: "drop.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)

                HStack {
                    TextField("0", text: Bindable(vm).amount)
                        .keyboardType(.numberPad)
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)

                    Text("ml")
                        .font(.title3.bold())
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                quickFillButtons
            }
            .padding()
            .background(accentColor.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)
        }
    }

    private var quickFillButtons: some View {
        HStack(spacing: 8) {
            ForEach([60, 80, 100, 120, 150, 180], id: \.self) { ml in
                Button("\(ml)") {
                    activityVM.amount = "\(ml)"
                }
                .font(.system(size: 13, weight: .medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    activityVM.amount == "\(ml)"
                        ? accentColor
                        : accentColor.opacity(0.1)
                )
                .foregroundStyle(
                    activityVM.amount == "\(ml)" ? .white : accentColor
                )
                .clipShape(Capsule())
            }
        }
    }

    // MARK: - Actions

    private func save() {
        guard let currentUserId = authVM.currentUserId,
              let baby = babyVM.selectedBaby else { return }
        let dataUserId = babyVM.dataUserId(currentUserId: currentUserId) ?? currentUserId
        isSaving = true
        AnalyticsService.shared.trackEvent(AnalyticsEvents.feedRecordSave, parameters: [AnalyticsParams.category: type.displayName])
        Task {
            await activityVM.saveActivity(userId: dataUserId, currentUserId: currentUserId, babyId: baby.id, type: type)
            guard activityVM.errorMessage == nil else {
                isSaving = false
                return
            }
            let feedAmount = Int(activityVM.amount)
            if let candidates = await productVM.deductStockForActivity(type, userId: currentUserId, recordedAmount: feedAmount) {
                productCandidates = candidates
            } else {
                isSaving = false
                onSaved?()
            }
        }
    }
}

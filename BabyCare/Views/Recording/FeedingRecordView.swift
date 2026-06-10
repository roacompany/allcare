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
        if type == .feedingBottle { return (Int(activityVM.amount) ?? 0) > 0 }
        if type == .feedingPumping { return (Int(activityVM.amount) ?? 0) > 0 }
        return true
    }

    // Accent colour per sub-type
    private var accentColor: Color {
        switch type {
        case .feedingBreast:  .pink
        case .feedingBottle:  AppColors.indigoColor
        case .feedingSolid:   AppColors.warmOrangeColor
        case .feedingSnack:   AppColors.sageColor
        case .feedingPumping: AppColors.pumpingColor
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
                pumpingSection(vm: vm)

                NoteField(note: $vm.note, accentColor: accentColor)
                    .padding(.horizontal)

                SaveButton(isSaving: isSaving, isEnabled: canSave, color: accentColor, action: save)
                    .padding(.horizontal)
                    .padding(.bottom, 16)
            }
            .padding(.top, 8)
        }
        .onAppear {
            AnalyticsService.shared.trackScreen(AnalyticsScreens.feedRecording)
            // 모유수유: 이전 기록의 반대편 자동 제안
            if type == .feedingBreast {
                if let lastSide = activityVM.lastFeeding?.side {
                    switch lastSide {
                    case .left:  activityVM.selectedSide = .right
                    case .right: activityVM.selectedSide = .left
                    case .both:  break
                    }
                }
            } else if type == .feedingPumping {
                activityVM.selectedSide = .both   // 유축 기본 방향
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
                Picker("내용물", selection: Bindable(vm).selectedFeedingContent) {
                    Text("분유").tag(Activity.FeedingContent.formula)
                    Text("유축한 모유").tag(Activity.FeedingContent.breastMilk)
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("병수유 내용물")
                .padding(.bottom, 4)

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

    @ViewBuilder
    private func pumpingSection(vm: ActivityViewModel) -> some View {
        if type == .feedingPumping {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    Label("유축량 (ml)", systemImage: "drop.fill")
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
                VStack(alignment: .leading, spacing: 10) {
                    Label("유축 방향", systemImage: "arrow.left.arrow.right")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)
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
                Text("유축 기록은 ‘짜낸 양’이에요. 아기가 실제로 먹은 양은 분유/모유 수유로 따로 기록해 주세요. 그래야 섭취량 통계와 병원 리포트가 정확해요.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
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
        Task {
            await activityVM.saveActivity(userId: dataUserId, currentUserId: currentUserId, babyId: baby.id, type: type)
            guard activityVM.errorMessage == nil else {
                isSaving = false
                return
            }
            trackSaveSuccess()
            let feedAmount = Int(activityVM.amount)
            // 유축한 모유 병수유는 분유 재고를 차감하지 않는다 (모유 ≠ formula)
            let skipFormulaDeduction = (type == .feedingBottle && activityVM.selectedFeedingContent == .breastMilk)
            if !skipFormulaDeduction,
               let candidates = await productVM.deductStockForActivity(type, userId: currentUserId, recordedAmount: feedAmount) {
                productCandidates = candidates
            } else {
                isSaving = false
                onSaved?()
            }
        }
    }

    /// 저장 성공 후 발화 (시도≠성공 혼재 방지). category 값은 영어 rawValue 고정.
    /// 유축은 섭취가 아니므로 feed_record_save 대신 pumping_recorded (생산/섭취 의료 격리와 동일 원칙).
    private func trackSaveSuccess() {
        if type == .feedingPumping {
            AnalyticsService.shared.trackEvent(AnalyticsEvents.pumpingRecorded, parameters: [
                AnalyticsParams.amountBucket: PumpingAnalytics.bucket(Double(activityVM.amount)),
                AnalyticsParams.side: activityVM.selectedSide.rawValue
            ])
            return
        }
        var params = [AnalyticsParams.category: type.rawValue]
        if type == .feedingBottle {
            params[AnalyticsParams.content] = activityVM.selectedFeedingContent.rawValue
        }
        AnalyticsService.shared.trackEvent(AnalyticsEvents.feedRecordSave, parameters: params)
    }
}

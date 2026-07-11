import SwiftUI

// MARK: - UnifiedRecordSheet
// 통합 기록 시트 — 상세(.detail) 타입 하나를 렌더하는 단일 시트. 서브타입 드릴다운 없음.
// FeedingRecordView / SleepRecordView / HealthRecordView / QuickInputSheet 를 대체(P1: 그리드 경로).
// VM 폼 상태 + P0 commit(draft:) 파이프라인으로 저장. 저장 후 onSaved(activity) 콜백(햅틱/토스트=호출자).

struct UnifiedRecordSheet: View {
    @Environment(ActivityViewModel.self) private var activityVM
    @Environment(BabyViewModel.self) private var babyVM
    @Environment(AuthViewModel.self) private var authVM
    @Environment(ProductViewModel.self) private var productVM
    @Environment(\.dismiss) private var dismiss

    let type: Activity.ActivityType
    var onSaved: ((Activity) -> Void)? = nil

    @State private var isSaving = false
    @State private var productCandidates: [BabyProduct] = []

    private var accent: Color { Self.accentColor(for: type) }
    private var showEndTime: Bool { type.needsTimer }

    private var canSave: Bool {
        switch type {
        case .feedingBottle, .feedingPumping: return (Int(activityVM.amount) ?? 0) > 0
        case .temperature: return Double(activityVM.temperatureInput) != nil
        case .medication: return !activityVM.medicationName.trimmingCharacters(in: .whitespaces).isEmpty
        default: return true
        }
    }

    var body: some View {
        @Bindable var vm = activityVM
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    header
                    TimeAdjustmentSection(accentColor: accent, showEndTime: showEndTime)
                    typeBody(vm: vm)
                    NoteField(note: $vm.note, accentColor: accent)
                        .padding(.horizontal)
                    SaveButton(isSaving: isSaving, isEnabled: canSave, color: accent, action: save)
                        .padding(.horizontal)
                        .padding(.bottom, 16)
                }
                .padding(.top, 8)
            }
            .navigationTitle(navTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { activityVM.resetForm(); dismiss() }
                        .foregroundStyle(.secondary)
                }
            }
            .onAppear { onAppear() }
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
                    let last = activityVM.todayActivities.first
                    productCandidates = []
                    finishSave(last)
                }
                .presentationDetents([.medium])
            }
        }
        .presentationDetents(type.needsTimer ? [.large] : [.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
    }

    private var navTitle: String {
        babyVM.selectedBaby.map { "\($0.name) · \(type.displayName)" } ?? type.displayName
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: type.icon)
                .font(.title2)
                .foregroundStyle(accent)
            Text(type.displayName)
                .font(.title3.bold())
                .foregroundStyle(.primary)
            Spacer()
        }
        .padding(.horizontal)
    }

    // MARK: - Type-specific body

    @ViewBuilder
    private func typeBody(vm: ActivityViewModel) -> some View {
        switch type {
        case .feedingBreast:
            VStack(spacing: 20) {
                TimerView(type: .feedingBreast, accentColor: accent)
                breastSideSection
            }
        case .feedingBottle:
            VStack(spacing: 20) {
                TimerView(type: .feedingBottle, accentColor: accent)
                bottleAmountSection(vm: vm)
            }
        case .feedingPumping:
            pumpingSection(vm: vm)
        case .feedingSolid:
            SolidFoodSection(accentColor: accent)
                .padding(.horizontal)
        case .sleep:
            VStack(spacing: 20) {
                TimerView(type: .sleep, accentColor: accent)
                sleepQualitySection
                sleepMethodSection
            }
        case .temperature:
            TemperatureSection(accentColor: accent)
        case .medication:
            MedicationSection(accentColor: accent)
        default:
            EmptyView()   // instant 타입(.diaper*/.bath/.snack)·.unknown 은 시트 미진입
        }
    }

    // MARK: - Breast side (from FeedingRecordView)

    private var breastSideSection: some View {
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
                    SideButton(side: side, isSelected: activityVM.selectedSide == side, color: accent) {
                        activityVM.selectedSide = side
                    }
                }
            }
        }
        .padding()
        .background(accent.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    // MARK: - Bottle amount (from FeedingRecordView)

    private func bottleAmountSection(vm: ActivityViewModel) -> some View {
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

            amountField(vm: vm)
            quickFillButtons
        }
        .padding()
        .background(accent.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    // MARK: - Pumping (from FeedingRecordView)

    private func pumpingSection(vm: ActivityViewModel) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                Label("유축량 (ml)", systemImage: "drop.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
                amountField(vm: vm)
                quickFillButtons
            }
            VStack(alignment: .leading, spacing: 10) {
                Label("유축 방향", systemImage: "arrow.left.arrow.right")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
                HStack(spacing: 12) {
                    ForEach(Activity.BreastSide.allCases, id: \.self) { side in
                        SideButton(side: side, isSelected: activityVM.selectedSide == side, color: accent) {
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
        .background(accent.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    private func amountField(vm: ActivityViewModel) -> some View {
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
    }

    private var quickFillButtons: some View {
        HStack(spacing: 8) {
            ForEach([60, 80, 100, 120, 150, 180], id: \.self) { ml in
                Button("\(ml)") { activityVM.amount = "\(ml)" }
                    .font(.system(size: 13, weight: .medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(activityVM.amount == "\(ml)" ? accent : accent.opacity(0.1))
                    .foregroundStyle(activityVM.amount == "\(ml)" ? .white : accent)
                    .clipShape(Capsule())
            }
        }
    }

    // MARK: - Sleep quality / method (from SleepRecordView)

    private var sleepQualitySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("수면 상태", systemImage: "moon.stars.fill")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
            HStack(spacing: 10) {
                ForEach(Activity.SleepQualityType.allCases, id: \.self) { quality in
                    Button {
                        activityVM.sleepQuality = activityVM.sleepQuality == quality ? nil : quality
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: quality.icon).font(.caption)
                            Text(quality.displayName).font(.caption.bold())
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(activityVM.sleepQuality == quality ? accent : accent.opacity(0.1))
                        .foregroundStyle(activityVM.sleepQuality == quality ? .white : accent)
                        .clipShape(Capsule())
                    }
                    .animation(.spring(duration: 0.25), value: activityVM.sleepQuality)
                }
            }
        }
        .padding()
        .background(accent.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    private var sleepMethodSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("잠든 곳", systemImage: "zzz")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
            FlowLayout(spacing: 8) {
                ForEach(Activity.SleepMethodType.selectableCases, id: \.self) { method in
                    Button {
                        activityVM.sleepMethod = activityVM.sleepMethod == method ? nil : method
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: method.icon).font(.caption)
                            Text(method.displayName).font(.caption.bold())
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(activityVM.sleepMethod == method ? accent : accent.opacity(0.1))
                        .foregroundStyle(activityVM.sleepMethod == method ? .white : accent)
                        .clipShape(Capsule())
                    }
                    .animation(.spring(duration: 0.25), value: activityVM.sleepMethod)
                }
            }
        }
        .padding()
        .background(accent.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    // MARK: - Lifecycle

    private func onAppear() {
        activityVM.resetForm()   // 그리드 진입: 스테일 폼 상태 제거
        AnalyticsService.shared.trackScreen(AnalyticsScreens.recording)
        activityVM.currentBabyName = babyVM.selectedBaby?.name ?? "아기"

        if type == .feedingBreast, let lastSide = activityVM.lastFeeding?.side {
            switch lastSide {
            case .left: activityVM.selectedSide = .right
            case .right: activityVM.selectedSide = .left
            case .both: break
            }
        } else if type == .feedingPumping {
            activityVM.selectedSide = .both
        }

        if type == .feedingBottle || type == .feedingPumping, activityVM.amount.isEmpty,
           let last = RecordPrefillPolicy.lastAmount(
               type: type,
               todayActivities: activityVM.todayActivities,
               recentActivities: activityVM.recentWeekActivities
           ) {
            activityVM.amount = last
        }
        if type == .feedingBottle,
           let content = RecordPrefillPolicy.lastFeedingContent(
               todayActivities: activityVM.todayActivities,
               recentActivities: activityVM.recentWeekActivities
           ) {
            activityVM.selectedFeedingContent = content
        }
    }

    // MARK: - Save (P0 commit 파이프라인)

    private func save() {
        guard let currentUserId = authVM.currentUserId, let baby = babyVM.selectedBaby else { return }
        let dataUserId = babyVM.dataUserId(currentUserId: currentUserId) ?? currentUserId
        isSaving = true
        Task {
            let draft = activityVM.makeDraft(type: type, babyId: baby.id)
            let saved = await activityVM.commit(draft: draft, userId: dataUserId, currentUserId: currentUserId)
            guard let saved, activityVM.errorMessage == nil else { isSaving = false; return }
            trackSaveSuccess()
            let feedAmount = Int(activityVM.amount)
            let skipFormula = (type == .feedingBottle && activityVM.selectedFeedingContent == .breastMilk)
            if !skipFormula,
               let candidates = await productVM.deductStockForActivity(type, userId: currentUserId, recordedAmount: feedAmount) {
                productCandidates = candidates   // ProductPickerSheet → finishSave
            } else {
                finishSave(saved)
            }
        }
    }

    private func finishSave(_ activity: Activity?) {
        isSaving = false
        if let activity { onSaved?(activity) }
        activityVM.resetForm()
        dismiss()
    }

    /// 그리드 경로 애널리틱스 계약 보존(dashboardQuickRecord / pumpingRecorded).
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
        AnalyticsService.shared.trackEvent(AnalyticsEvents.dashboardQuickRecord, parameters: params)
    }

    // MARK: - Accent

    static func accentColor(for type: Activity.ActivityType) -> Color {
        switch type {
        case .feedingBreast: return .pink
        case .feedingBottle: return AppColors.indigoColor
        case .feedingSolid, .feedingSnack: return AppColors.warmOrangeColor
        case .feedingPumping: return AppColors.pumpingColor
        case .sleep: return AppColors.indigoColor
        case .temperature: return AppColors.coralColor
        case .medication: return AppColors.softPurpleColor
        case .diaperWet, .diaperDirty, .diaperBoth: return AppColors.sageColor
        case .bath: return AppColors.skyBlueColor
        case .unknown: return AppColors.neutralGray
        }
    }
}

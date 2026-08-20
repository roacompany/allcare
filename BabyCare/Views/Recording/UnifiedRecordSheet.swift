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
    /// 분유/유축 타일 프리셋 (feedingBottle 전용) — 지정 시 히스토리 프리필보다 우선, 제목도 유축/분유 반영.
    var contentPreset: Activity.FeedingContent? = nil
    var onSaved: ((Activity) -> Void)? = nil

    @State private var isSaving = false
    @State private var productCandidates: [BabyProduct] = []

    /// 유축 허브 모드 (A안, 2026-08-20 PO 승인) — [유축(생산) | 먹이기(섭취=모유(병))] 한 공간.
    private enum PumpHubMode { case pump, feed }
    @State private var pumpMode: PumpHubMode = .pump

    private var isPumpFeedMode: Bool { type == .feedingPumping && pumpMode == .feed }

    // 액센트 = Activity 단일 소스(emphasisColor). 허브 '먹이기' 모드는 섭취라 수유 계열 색.
    private var accent: Color {
        Color(isPumpFeedMode ? Activity.ActivityType.feedingBottle.emphasisColor : type.emphasisColor)
    }
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
                    // header 제거 — 내비 제목이 이미 '아기 · 타입'(3중 제목 해소, 2026-08-20 재작업)
                    TimeAdjustmentSection(accentColor: accent, showEndTime: showEndTime)
                    typeBody(vm: vm)
                    NoteField(note: $vm.note, accentColor: accent)
                        .padding(.horizontal)
                        .padding(.bottom, 12)
                }
                .padding(.top, 8)
            }
            .safeAreaInset(edge: .bottom) {
                SaveBar(isSaving: isSaving, isEnabled: canSave, color: accent, action: save)
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
        .presentationDetents([.large])   // 전체 높이로 표시 — 반높이(.medium)면 폼이 잘려 "레이어 안 올라옴"
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
    }

    /// 타일 라벨 — 유축(breastMilk 병)은 '유축', 분유는 '분유', 그 외 type.displayName. (RecordTile 단일 소스)
    private var tileLabel: String { RecordTile(type, content: contentPreset).label }

    private var navTitle: String {
        babyVM.selectedBaby.map { "\($0.name) · \(tileLabel)" } ?? tileLabel
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
            // 유축 허브 (A안) — 생산(유축)과 사용(먹이기=모유(병))이 한 공간. 기록 종류는 그대로 둘.
            VStack(spacing: 16) {
                pumpModePicker
                if pumpMode == .pump {
                    pumpingSection(vm: vm)
                } else {
                    pumpFeedSection(vm: vm)
                }
            }
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
                // 라벨 = FeedingContent.displayName 단일 소스 — '유축/유축한 모유' 혼용 제거 (2026-08-20 용어 한 벌)
                ForEach(Activity.FeedingContent.allCases, id: \.self) { content in
                    Text(content.displayName).tag(content)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("병수유 내용물")
            .padding(.bottom, 4)

            if vm.selectedFeedingContent == .breastMilk, vm.pumpInventory.totalRemaining > 0 {
                Label("유축한 모유 약 \(Int(vm.pumpInventory.totalRemaining))mL 남아 있어요 (최근 기록 기준)", systemImage: "drop.fill")
                    .font(.caption)
                    .foregroundStyle(AppColors.pumpingEmphasis)
                    .padding(.bottom, 4)
            }

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
            VStack(alignment: .leading, spacing: 10) {
                Label("보관 방법", systemImage: "snowflake")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
                Picker("보관", selection: Bindable(vm).selectedPumpStorage) {
                    ForEach(PumpStorage.allCases, id: \.self) { storage in
                        Text(storage.displayName).tag(storage)
                    }
                }
                .pickerStyle(.segmented)
                // 고른 보관의 유통기한만 한 줄로 — 세 값 나열 문단 제거 (2026-08-20 안내 압축)
                HStack(spacing: 6) {
                    Image(systemName: "snowflake")
                        .font(.caption2)
                        .foregroundStyle(accent)
                    Text("\(vm.selectedPumpStorage.displayName) 보관 · 유통기한 \(vm.selectedPumpStorage.expiryText)")
                        .font(.caption.weight(.semibold))
                    Text("(초안 · 참고용)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            DisclosureGroup {
                Text("‘유축’은 아기가 먹은 기록이 아니라 유축한 양(생산)이에요. 실제로 먹인 건 모유·분유·모유(병)로 따로 기록해 주세요. 그래야 섭취량 통계와 병원 리포트가 정확해요.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            } label: {
                Label("왜 유축은 먹인 기록이 아닌가요?", systemImage: "info.circle")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .tint(.secondary)
        }
        .padding()
        .background(accent.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    // MARK: - 유축 허브 (A안, 2026-08-20)

    private var pumpModePicker: some View {
        HStack(spacing: 8) {
            pumpModeButton(.pump, icon: "drop.fill", label: "유축")
            pumpModeButton(.feed, icon: "waterbottle.fill", label: "먹이기")
        }
        .padding(.horizontal)
    }

    private func pumpModeButton(_ mode: PumpHubMode, icon: String, label: String) -> some View {
        let isSelected = pumpMode == mode
        let color = Color(mode == .pump
            ? Activity.ActivityType.feedingPumping.emphasisColor
            : Activity.ActivityType.feedingBottle.emphasisColor)
        return Button {
            guard pumpMode != mode else { return }
            withAnimation(.spring(duration: 0.25)) { pumpMode = mode }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .accessibilityHidden(true)
                Text(label)
                    .font(.subheadline.weight(.bold))
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(isSelected ? color : Color(.systemGray6))
            .foregroundStyle(isSelected ? Color.white : Color.secondary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    /// '먹이기' 모드 — 유축한 모유 병수유. 저장은 모유(병)(feedingBottle + breastMilk)로 = 섭취 통계·재고 차감 그대로.
    private func pumpFeedSection(vm: ActivityViewModel) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if vm.pumpInventory.totalRemaining > 0 {
                Label("유축한 모유 약 \(Int(vm.pumpInventory.totalRemaining))mL 보관 중 · 오래된 것부터 차감돼요",
                      systemImage: "drop.fill")
                    .font(.caption)
                    .foregroundStyle(AppColors.pumpingEmphasis)
            }
            VStack(alignment: .leading, spacing: 10) {
                Label("먹인 양 (ml)", systemImage: "drop.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
                amountField(vm: vm)
                quickFillButtons
            }
            if let fed = Int(vm.amount), fed > 0, vm.pumpInventory.totalRemaining > 0 {
                Text("저장하면 약 \(max(0, Int(vm.pumpInventory.totalRemaining) - fed))mL 남아요")
                    .font(.caption)
                    .foregroundStyle(AppColors.pumpingEmphasis)
            }
            Text("이 기록은 먹인 것(섭취)으로 저장돼요 — 통계와 병원 리포트에 ‘모유(병)’로 들어가요.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
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
        if type == .feedingBottle {
            if let contentPreset {
                activityVM.selectedFeedingContent = contentPreset   // 타일 프리셋(분유/유축)이 히스토리보다 우선
            } else if let content = RecordPrefillPolicy.lastFeedingContent(
                todayActivities: activityVM.todayActivities,
                recentActivities: activityVM.recentWeekActivities
            ) {
                activityVM.selectedFeedingContent = content
            }
        }
    }

    // MARK: - Save (P0 commit 파이프라인)

    private func save() {
        guard let currentUserId = authVM.currentUserId, let baby = babyVM.selectedBaby else { return }
        let dataUserId = babyVM.dataUserId(currentUserId: currentUserId) ?? currentUserId
        // 유축 허브 '먹이기' 모드 = 모유(병) 기록 — 저장 타입은 feedingBottle + breastMilk (섭취 통계·재고 차감 그대로).
        let saveType: Activity.ActivityType = isPumpFeedMode ? .feedingBottle : type
        if isPumpFeedMode { activityVM.selectedFeedingContent = .breastMilk }
        isSaving = true
        Task {
            let draft = activityVM.makeDraft(type: saveType, babyId: baby.id)
            let saved = await activityVM.commit(draft: draft, userId: dataUserId, currentUserId: currentUserId)
            guard let saved, activityVM.errorMessage == nil else { isSaving = false; return }
            trackSaveSuccess(saveType: saveType)
            let feedAmount = Int(activityVM.amount)
            let skipFormula = (saveType == .feedingBottle && activityVM.selectedFeedingContent == .breastMilk)
            if !skipFormula,
               let candidates = await productVM.deductStockForActivity(saveType, userId: currentUserId, recordedAmount: feedAmount) {
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
    /// 허브 '먹이기' 모드는 실제 저장 타입(feedingBottle)으로 발화 — GA4 차원 일관.
    private func trackSaveSuccess(saveType: Activity.ActivityType) {
        if saveType == .feedingPumping {
            AnalyticsService.shared.trackEvent(AnalyticsEvents.pumpingRecorded, parameters: [
                AnalyticsParams.amountBucket: PumpingAnalytics.bucket(Double(activityVM.amount)),
                AnalyticsParams.side: activityVM.selectedSide.rawValue
            ])
            return
        }
        var params = [AnalyticsParams.category: saveType.rawValue]
        if saveType == .feedingBottle {
            params[AnalyticsParams.content] = activityVM.selectedFeedingContent.rawValue
        }
        AnalyticsService.shared.trackEvent(AnalyticsEvents.dashboardQuickRecord, parameters: params)
    }
}

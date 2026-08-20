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

    // 액센트 = Activity 단일 소스(emphasisColor) — "한 활동 = 한 색".
    // (기존: 분유=인디고(수면 색)·간식=세이지(기저귀 색) 등 폼 자체 색 → 2026-08-20 재작업으로 제거)
    private var accentColor: Color { Color(type.emphasisColor) }

    var body: some View {
        @Bindable var vm = activityVM

        ScrollView {

            VStack(spacing: 20) {
                // typeHeader 제거 — 내비 제목 + 선택된 칩이 이미 같은 정보(3중 제목 해소, 2026-08-20 재작업)
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
                    .padding(.bottom, 12)
            }
            .padding(.top, 8)
        }
        .safeAreaInset(edge: .bottom) {
            SaveBar(isSaving: isSaving, isEnabled: canSave, color: accentColor, action: save)
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
            // B3: 직전 값 프리필 — 사용자가 이미 입력했으면(비어있지 않으면) 유지
            if (type == .feedingBottle || type == .feedingPumping), activityVM.amount.isEmpty,
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
                    // 라벨 = FeedingContent.displayName 단일 소스 — '유축/유축한 모유' 혼용 제거 (2026-08-20 용어 한 벌)
                    ForEach(Activity.FeedingContent.allCases, id: \.self) { content in
                        Text(content.displayName).tag(content)
                    }
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
                            .foregroundStyle(accentColor)
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

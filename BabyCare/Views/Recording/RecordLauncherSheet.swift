import SwiftUI

// MARK: - RecordLauncherSheet
// ＋탭 '기록하기' — 어디서든 여는 타입-우선 런처. RecordingView(카테고리 드릴다운)를 대체(P3).
// 타일 탭 → RecordEntryRule: instant(즉시 저장+되돌리기, 런처 유지) / detail(UnifiedRecordSheet).
// 카테고리는 시각적 섹션일 뿐(인터랙션 레이어 아님) — 타일 하나 = 구체 타입.

struct RecordLauncherSheet: View {
    @Environment(ActivityViewModel.self) private var activityVM
    @Environment(BabyViewModel.self) private var babyVM
    @Environment(AuthViewModel.self) private var authVM
    @Environment(ProductViewModel.self) private var productVM

    @State private var detailTile: RecordTile?
    @State private var savedFeedback: Activity.ActivityType?
    @State private var lastSaved: Activity?
    @State private var productCandidates: [BabyProduct] = []

    // 카테고리별 시각 섹션 (정렬만 — 각 타일은 구체 타입/프리셋). 분유·유축은 content 프리셋으로 분리.
    private let sections = RecordTile.launcherSections

    // 빈도 위계: 자주=큰 타일(적은 열) / 가끔=작은 타일(많은 열).
    private func columns(for prominence: RecordTileProminence) -> [GridItem] {
        switch prominence {
        case .frequent:   return [GridItem(.adaptive(minimum: 78), spacing: 12)]
        case .occasional: return [GridItem(.adaptive(minimum: 62), spacing: 10)]
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    ForEach(sections) { section in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(section.title)
                                .font(.subheadline.bold())
                                .foregroundStyle(.secondary)
                            LazyVGrid(columns: columns(for: section.prominence),
                                      spacing: section.prominence == .frequent ? 12 : 10) {
                                ForEach(section.tiles) { tile in
                                    QuickActionButton(tile: tile) { await tap(tile) }
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("기록하기")
            .navigationBarTitleDisplayMode(.inline)
            .overlay(alignment: .bottom) { feedbackBar }
            .animation(.easeInOut, value: savedFeedback)
            .sheet(item: $detailTile) { tile in
                UnifiedRecordSheet(type: tile.type, contentPreset: tile.contentPreset,
                                   onSaved: { activity in showSaved(activity) })
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
                }
                .presentationDetents([.medium])
            }
        }
    }

    // MARK: - Feedback bar (인라인 · 되돌리기)

    @ViewBuilder
    private var feedbackBar: some View {
        if let type = savedFeedback {
            let title = lastSaved?.displayLabel ?? type.displayName
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.white)
                Text("\(title) 저장됨")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                if let saved = lastSaved {
                    Divider()
                        .frame(height: 16)
                        .overlay(.white.opacity(0.5))
                    Button("되돌리기") { undo(saved) }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Capsule().fill(Color(type.color)))
            .padding(.bottom, 16)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: - Tap routing

    private func tap(_ tile: RecordTile) async {
        switch RecordEntryRule.mode(for: tile.type) {
        case .detail:
            detailTile = tile
        case .instant:
            let type = tile.type
            guard let currentUserId = authVM.currentUserId, let baby = babyVM.selectedBaby else { return }
            let dataUserId = babyVM.dataUserId(currentUserId: currentUserId) ?? currentUserId
            await activityVM.quickSave(userId: dataUserId, currentUserId: currentUserId, babyId: baby.id, type: type)
            if activityVM.errorMessage == nil {
                AnalyticsService.shared.trackEvent(AnalyticsEvents.dashboardQuickRecord, parameters: [AnalyticsParams.category: type.rawValue])
            }
            showSaved(activityVM.todayActivities.first)
            if let candidates = await productVM.deductStockForActivity(type, userId: currentUserId) {
                productCandidates = candidates
            }
        case .timer:
            // 모유 등 시간-기록: 탭 → 타이머 즉시 시작 → '수유 중' 배너(오버레이). 정지 시 배너가 시간과 함께 저장.
            let type = tile.type
            guard let currentUserId = authVM.currentUserId, let baby = babyVM.selectedBaby else { return }
            let dataUserId = babyVM.dataUserId(currentUserId: currentUserId) ?? currentUserId
            activityVM.startTimedRecord(type: type, userId: dataUserId, currentUserId: currentUserId, babyId: baby.id)
            AnalyticsService.shared.trackEvent(AnalyticsEvents.dashboardQuickRecord, parameters: [AnalyticsParams.category: type.rawValue])
        }
    }

    // MARK: - Feedback

    private func showSaved(_ activity: Activity?) {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        lastSaved = activity
        withAnimation(.spring(duration: 0.3)) { savedFeedback = activity?.type }
        Task {
            try? await Task.sleep(for: .seconds(3))
            withAnimation { savedFeedback = nil; lastSaved = nil }
        }
    }

    private func undo(_ activity: Activity) {
        if let currentUserId = authVM.currentUserId {
            let dataUserId = babyVM.dataUserId(currentUserId: currentUserId) ?? currentUserId
            Task { await activityVM.deleteActivity(activity, userId: dataUserId) }
        }
        withAnimation { savedFeedback = nil; lastSaved = nil }
    }
}

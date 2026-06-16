import SwiftUI

/// ② 기록·추적 허브 (SCREENS.md §②기록). 세그먼트 + 오늘 요약 + 도구 카드.
/// 저장은 공유 PregnancyViewModel 통해 ①여정으로 역류.
/// 상태별(혈압/혈당·진통)=Phase B/C, 선택 모듈(약/수분/수면)=Phase D 에서 채움.
@MainActor
struct PregnancyTrackingHubView: View {
    @Environment(PregnancyViewModel.self) private var pregnancyVM

    @State private var segment: TrackingSegment = .daily
    @State private var activeSheet: TrackingSheet?
    @State private var showVitals = false

    private enum TrackingSheet: Int, Identifiable {
        case kick, weight, symptom
        var id: Int { rawValue }
    }

    private var summary: PregnancyTrackingSummary {
        PregnancyTrackingSummary(
            now: Date(),
            kickSessions: pregnancyVM.kickSessions,
            weightEntries: pregnancyVM.weightEntries,
            symptoms: pregnancyVM.symptoms
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: DS2.Spacing.lg) {
                TodaySummaryStrip(summary: summary)

                Picker("도구 분류", selection: $segment) {
                    ForEach(TrackingSegment.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                switch segment {
                case .daily: dailyTools
                case .conditional: conditionalTools
                case .optional: optionalTools
                }
            }
            .padding(.horizontal, DS2.Spacing.lg)
            .padding(.vertical, DS2.Spacing.lg)
        }
        .navigationTitle("기록")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showVitals) { PregnancyVitalsView() }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .kick: KickRecordingSheet()
            case .weight: PregnancyWeightEntrySheet()
            case .symptom: PregnancySymptomMemoSheet()
            }
        }
    }

    // MARK: - 매일 도구 (기존 시트 재사용)

    @ViewBuilder private var dailyTools: some View {
        TrackingToolCard(icon: "hand.tap.fill", title: "태동 카운터",
                         subtitle: "ACOG 2시간 내 10회 기준", action: { activeSheet = .kick })
        TrackingToolCard(icon: "scalemass.fill", title: "체중",
                         subtitle: "임신 전 대비 증가 추이", action: { activeSheet = .weight })
        TrackingToolCard(icon: "face.smiling", title: "증상 / 기분",
                         subtitle: "오늘 컨디션을 기록", action: { activeSheet = .symptom })
    }

    // MARK: - 상태별 (Phase B/C)

    @ViewBuilder private var conditionalTools: some View {
        TrackingToolCard(icon: "heart.text.square", title: "혈압 / 혈당",
                         subtitle: "임당 참고 목표선 비교", action: { showVitals = true })
        // 진통 간격 타이머(5-1-1)는 Phase C 에서 제공.
        Text("진통 간격 타이머(5-1-1)는 곧 제공됩니다.")
            .font(DS2.Font.caption).foregroundStyle(DS2.Color.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 선택 모듈 (Phase D)

    @ViewBuilder private var optionalTools: some View {
        ContentUnavailableView("준비 중", systemImage: "switch.2",
                               description: Text("약·수분·수면 모듈이 곧 제공됩니다."))
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    let vm = PregnancyViewModel()
    vm.activePregnancy = Pregnancy(
        lmpDate: Calendar.current.date(byAdding: .day, value: -168, to: Date()),
        dueDate: Calendar.current.date(byAdding: .day, value: 112, to: Date()),
        fetusCount: 1, babyNickname: "둘째"
    )
    return NavigationStack { PregnancyTrackingHubView() }
        .environment(vm).tint(DS2.Color.pregnancy)
}
#endif

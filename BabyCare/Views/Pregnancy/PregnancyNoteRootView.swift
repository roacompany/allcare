import SwiftUI

// MARK: - PregnancyNoteRootView

/// 임신 노트 4탭 셸 (보라/라일락 액센트).
///
/// 진입:
/// - `.both` AppContext: 육아홈 PregnancyPortalCard 탭 → .fullScreenCover로 이 화면.
///   `showsExitChip = true`, `onExit`으로 cover dismiss 전달.
/// - `.pregnancyOnly` AppContext: 이 화면이 앱 루트 (fullScreenCover 아님).
///   `showsExitChip = false`, `onExit`은 쓰이지 않음.
///
/// 셸 자체는 자체 ViewModel 없음 — `@Environment`로 부모가 주입한 PregnancyViewModel 상속.
/// 실제 탭 콘텐츠 구현은 서브프로젝트 3~5에서 진행 (현재 stub 뷰).
@MainActor
struct PregnancyNoteRootView: View {
    // MARK: - Init

    /// both 모드일 때 true — 상단 공간칩([← 육아로]) 표시.
    let showsExitChip: Bool

    /// both 모드에서 공간칩 탭 시 호출 — Part B에서 fullScreenCover dismiss로 배선.
    let onExit: () -> Void

    // MARK: - State

    /// 마지막 선택 탭. 부모(cover 호출측)가 보유하면 재진입 시도 보존됨.
    @State private var selectedTab: Int = 0

    // MARK: - Environment

    @Environment(PregnancyViewModel.self) private var pregnancyVM

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .top) {
            // (0) 공간 배경: 라일락 워시 그라데이션 — 다크모드 대응(저채도 보라)
            pregnancyBackground

            // (1) + (2) + (3): 공간칩 + TabView 콘텐츠 + 하단 탭바
            TabView(selection: $selectedTab) {
                // ① 여정
                NavigationStack {
                    PregnancyJourneyView()
                        .toolbar {
                            if showsExitChip {
                                ToolbarItem(placement: .topBarLeading) {
                                    PregnancySpaceChip(
                                        pregnancyVM: pregnancyVM,
                                        onExit: onExit,
                                        onJumpToJourney: { selectedTab = 0 }
                                    )
                                }
                            }
                        }
                }
                .tabItem {
                    Label("여정", systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                }
                .tag(0)

                // ② 기록
                NavigationStack {
                    PregnancyTrackingHubView()
                        .toolbar {
                            if showsExitChip {
                                ToolbarItem(placement: .topBarLeading) {
                                    PregnancySpaceChip(
                                        pregnancyVM: pregnancyVM,
                                        onExit: onExit,
                                        onJumpToJourney: { selectedTab = 0 }
                                    )
                                }
                            }
                        }
                }
                .tabItem {
                    Label("기록", systemImage: "square.and.pencil")
                }
                .tag(1)

                // ③ 검진
                NavigationStack {
                    PrenatalCareView()
                        .toolbar {
                            if showsExitChip {
                                ToolbarItem(placement: .topBarLeading) {
                                    PregnancySpaceChip(
                                        pregnancyVM: pregnancyVM,
                                        onExit: onExit,
                                        onJumpToJourney: { selectedTab = 0 }
                                    )
                                }
                            }
                        }
                }
                .tabItem {
                    Label("검진", systemImage: "stethoscope")
                }
                .tag(2)

                // ④ 더보기
                NavigationStack {
                    PregnancyMoreView()
                        .toolbar {
                            if showsExitChip {
                                ToolbarItem(placement: .topBarLeading) {
                                    PregnancySpaceChip(
                                        pregnancyVM: pregnancyVM,
                                        onExit: onExit,
                                        onJumpToJourney: { selectedTab = 0 }
                                    )
                                }
                            }
                        }
                }
                .tabItem {
                    Label("더보기", systemImage: "ellipsis.circle")
                }
                .tag(3)
            }
            .tint(DS2.Color.pregnancy)
        }
        .ignoresSafeArea(edges: .top)
    }

    // MARK: - Background

    private var pregnancyBackground: some View {
        LinearGradient(
            colors: [
                DS2.Color.tintPurple.opacity(0.10),
                DS2.Color.tintPurple.opacity(0)
            ],
            startPoint: .top,
            endPoint: .center
        )
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

// MARK: - PregnancySpaceChip

/// 상단 공간칩: [← 육아로] 가역 종료 + "🤰 임신N주" 컨텍스트.
/// SCREENS.md §PregnancyNoteRootView 컴포넌트 명세.
/// both 모드에서만 인스턴스화(pregnancyOnly는 나갈 곳 없으므로 렌더 안 함).
private struct PregnancySpaceChip: View {
    let pregnancyVM: PregnancyViewModel
    let onExit: () -> Void
    let onJumpToJourney: () -> Void

    var body: some View {
        HStack(spacing: DS2.Spacing.sm) {
            // [← 육아로] 캡슐 버튼
            exitButton

            // 🤰 임신N주 컨텍스트 라벨 (탭 시 ① 여정으로 점프)
            contextLabel
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: Exit Button

    private var exitButton: some View {
        Button(action: onExit) {
            ViewThatFits {
                // 기본: 아이콘 + 텍스트
                HStack(spacing: 4) {
                    Image(systemName: "chevron.backward")
                        .font(.caption.weight(.semibold))
                    Text("육아로")
                        .font(DS2.Font.caption)
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, DS2.Spacing.md)
                .padding(.vertical, DS2.Spacing.xs)
                .background(DS2.Color.tintPurple)
                .foregroundStyle(DS2.Color.pregnancy)
                .clipShape(Capsule())

                // AccessibilityXXXL 축소: 아이콘만 (H-8 선례)
                Image(systemName: "chevron.backward")
                    .font(.caption.weight(.semibold))
                    .padding(DS2.Spacing.xs)
                    .background(DS2.Color.tintPurple)
                    .foregroundStyle(DS2.Color.pregnancy)
                    .clipShape(Circle())
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("육아 공간으로 돌아가기")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: Context Label

    private var contextLabel: some View {
        Button(action: onJumpToJourney) {
            HStack(spacing: 4) {
                Image(systemName: "figure.and.child.holdinghands")
                    .font(.caption2)
                Text(contextText)
                    .font(DS2.Font.caption)
            }
            .foregroundStyle(DS2.Color.pregnancy.opacity(0.8))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(contextAccessibilityLabel)
    }

    // MARK: Helpers

    private var contextText: String {
        if let wd = pregnancyVM.currentWeekAndDay {
            return "임신 \(wd.weeks)주"
        }
        return "임신중"
    }

    private var contextAccessibilityLabel: String {
        if let wd = pregnancyVM.currentWeekAndDay,
           let dDay = pregnancyVM.dDay {
            return "현재 임신 \(wd.weeks)주 \(wd.days)일, D-\(dDay)"
        } else if let wd = pregnancyVM.currentWeekAndDay {
            return "현재 임신 \(wd.weeks)주 \(wd.days)일"
        }
        return "임신 중"
    }
}

// MARK: - Preview

#if DEBUG
#Preview("both 모드 (공간칩 표시)") {
    let vm = PregnancyViewModel()
    vm.activePregnancy = Pregnancy(
        lmpDate: Calendar.current.date(byAdding: .day, value: -168, to: Date()),
        dueDate: Calendar.current.date(byAdding: .day, value: 112, to: Date()),
        fetusCount: 1,
        babyNickname: "둘째"
    )
    return PregnancyNoteRootView(showsExitChip: true, onExit: {})
        .environment(vm)
}

#Preview("pregnancyOnly 모드 (공간칩 없음)") {
    let vm = PregnancyViewModel()
    vm.activePregnancy = Pregnancy(
        lmpDate: Calendar.current.date(byAdding: .day, value: -84, to: Date()),
        dueDate: Calendar.current.date(byAdding: .day, value: 196, to: Date()),
        fetusCount: 1,
        babyNickname: "아기"
    )
    return PregnancyNoteRootView(showsExitChip: false, onExit: {})
        .environment(vm)
}
#endif

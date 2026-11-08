import SwiftUI

/// 더 보기 칸의 목록 — 아래 바에 「여행」이 들어가 칸이 넘쳐 건강·설정을 여기 모은다(설계 2026-11-05 §1).
enum MoreItem: String, Hashable, Identifiable, CaseIterable {
    case health, settings
    var id: String { rawValue }
}

/// 직접 만든 「더 보기」 — 아이폰 기본 「더 보기」는 칸 화면을 자기 내비게이션 안에 넣어
/// 건강·설정의 NavigationStack 과 겹친다(중첩 금지). 그래서 고른 화면을 그대로 열고, 그 화면 왼쪽 위 「더 보기」로 돌아온다.
struct MoreTabView: View {
    @Binding var selection: MoreItem?

    var body: some View {
        switch selection {
        case .health:
            HealthView(onBackToMore: { selection = nil })
                .onAppear { AnalyticsService.shared.trackScreen(AnalyticsScreens.health) }
        case .settings:
            SettingsView(onBackToMore: { selection = nil })
                .onAppear { AnalyticsService.shared.trackScreen(AnalyticsScreens.settings) }
        case nil:
            NavigationStack {
                List {
                    row(.health, title: "건강", icon: "heart.text.clipboard.fill")
                    row(.settings, title: "설정", icon: "gearshape.fill")
                }
                .listStyle(.insetGrouped)
                .navigationTitle("더 보기")
            }
        }
    }

    private func row(_ item: MoreItem, title: String, icon: String) -> some View {
        Button {
            selection = item
        } label: {
            HStack {
                Label(title, systemImage: icon)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .foregroundStyle(.primary)
    }
}

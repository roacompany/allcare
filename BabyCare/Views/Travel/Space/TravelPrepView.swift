import SwiftUI

/// 준비 칸의 두 칸 — 할 일 · 규칙(시안 Trip-Todo · Trip-Rules).
enum TravelPrepSection: String, CaseIterable, Identifiable, Hashable {
    case tasks, rules

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tasks: return "할 일"
        case .rules: return "규칙"
        }
    }
}

/// 준비 칸(캔버스 Version 84) — 머리 「준비」 + 밑줄 칸(할 일 | 규칙) · 할 일 = 담당 거르기 + 주별 목록 + 알림 · 규칙 = 이 여행의 규칙 + 공항 시설.
/// 담당 거르기·칸은 여행 공간이 쥔다 — 홈 「n개」가 할 일·전체로 연다.
struct TravelPrepView: View {
    let vm: TripDetailViewModel
    @Binding var section: TravelPrepSection
    @Binding var filter: TripAssigneeFilter

    var body: some View {
        VStack(spacing: 0) {
            TravelScreenHeader(title: "준비", subtitle: TripHeaderText.subtitle(vm.trip, calendar: vm.calendar))
            TravelUnderlineTabs(items: TravelPrepSection.allCases, selection: $section, title: { $0.title })
            TravelList {
                TripStatusRows(vm: vm)
                switch section {
                case .tasks:
                    TripTasksSection(vm: vm, filter: $filter)
                    TripReminderSettings(vm: vm)
                case .rules:
                    TripRulesSection(vm: vm)
                }
            }
        }
        .background(TravelStyle.page)
    }
}

/// 알림(이 폰) — 마감 3일 전 · 마감 전날. 옛 가족 칸에 있던 것(짜임을 바꾸며 준비 칸 할 일 아래로 옮겼다).
/// 모양 = 옛 가족 칸 그대로: 띠 · 「알림」 16 굵게(높이 32 · 위 12) · 한 줄 높이 52 · 아래 1px 선 · 스위치 primary.
struct TripReminderSettings: View {
    let vm: TripDetailViewModel

    var body: some View {
        TravelBandRow()
        Text("알림")
            .travelFont(16, .semibold)
            .foregroundStyle(TravelStyle.ink)
            .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
            .travelRow(top: 12)
        toggle("마감 3일 전", isOn: vm.reminderOptions.threeDaysBefore) { options, value in options.threeDaysBefore = value }
        toggle("마감 전날", isOn: vm.reminderOptions.dayBefore) { options, value in options.dayBefore = value }
        Color.clear
            .frame(height: 20)
            .travelRow()
    }

    private func toggle(_ title: String, isOn: Bool, apply: @escaping (inout TripReminderOptions, Bool) -> Void) -> some View {
        Toggle(isOn: Binding(
            get: { isOn },
            set: { value in
                var options = vm.reminderOptions
                apply(&options, value)
                Task { await vm.setReminderOptions(options) }
            })) {
            Text(title)
                .travelFont(15)
                .foregroundStyle(TravelStyle.ink)
        }
        .tint(TravelStyle.primary)
        .frame(minHeight: 52)
        .overlay(alignment: .bottom) { TravelHairline() }
        .travelRow()
    }
}

import SwiftUI
import UserNotifications

// MARK: - NotificationSettingsView

struct NotificationSettingsView: View {
    @State private var rules = ActivityReminderSettings.rules
    @State private var vaccinationEnabled = NotificationSettings.vaccinationReminderEnabled
    @State private var vaccinationDays = NotificationSettings.vaccinationDaysBefore
    @State private var reorderEnabled = NotificationSettings.reorderReminderEnabled
    @State private var notificationPermission: Bool = true

    private let intervalOptions: [Int] = [30, 60, 90, 120, 180, 240, 360, 480, 720, 1440]

    private let vaccinationDayOptions: [Int] = [0, 1, 3, 7, 14, 30]

    var body: some View {
        List {
            if !notificationPermission {
                Section {
                    HStack(spacing: 10) {
                        Image(systemName: "bell.slash.fill")
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("알림이 꺼져 있습니다")
                                .font(.subheadline.weight(.semibold))
                            Text("설정 앱 > 베이비케어 > 알림에서 허용해주세요.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Link("설정 열기", destination: URL(string: UIApplication.openSettingsURLString)!)
                            .font(.caption.weight(.medium))
                    }
                    .padding(.vertical, 4)
                }
            }

            // 활동별 알림
            Section {
                ForEach($rules) { $rule in
                    Toggle(isOn: $rule.enabled) {
                        HStack(spacing: 10) {
                            if let type = rule.type {
                                Image(systemName: type.icon)
                                    .font(.body)
                                    .foregroundStyle(Color(type.color))
                                    .frame(width: 24)
                            }
                            Text(rule.displayName)
                        }
                    }
                    .onChange(of: rule.enabled) { _, newVal in
                        saveRules()
                        if !newVal, let type = rule.type {
                            NotificationService.shared.cancelActivityReminder(type: type)
                        }
                    }

                    if rule.enabled {
                        Picker(selection: $rule.intervalMinutes) {
                            ForEach(intervalOptions, id: \.self) { mins in
                                Text(intervalLabel(mins)).tag(mins)
                            }
                        } label: {
                            HStack(spacing: 10) {
                                Color.clear.frame(width: 24)
                                Text("알림 간격")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .onChange(of: rule.intervalMinutes) { _, _ in
                            saveRules()
                        }
                    }
                }
            } header: {
                Text("활동 기록 알림")
            } footer: {
                Text("기록 후 설정한 시간이 지나면 알림을 보냅니다. 원하는 활동만 켜세요.")
            }

            // 접종 알림
            Section {
                Toggle("접종 알림", isOn: $vaccinationEnabled)
                    .onChange(of: vaccinationEnabled) { _, val in
                        NotificationSettings.vaccinationReminderEnabled = val
                    }

                if vaccinationEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("알림 시점")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        FlowLayout(spacing: 8) {
                            ForEach(vaccinationDayOptions, id: \.self) { day in
                                let isSelected = vaccinationDays.contains(day)
                                Button {
                                    toggleVaccinationDay(day)
                                } label: {
                                    Text(vaccinationDayLabel(day))
                                        .font(.caption.weight(.medium))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(
                                            Capsule()
                                                .fill(isSelected ? Color.blue.opacity(0.15) : Color.secondary.opacity(0.1))
                                        )
                                        .foregroundStyle(isSelected ? .blue : .secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text("예방접종")
            } footer: {
                Text("예정된 접종일 기준, 선택한 시점에 알림을 보냅니다.")
            }

            // 재구매
            Section {
                Toggle("재구매 알림", isOn: $reorderEnabled)
                    .onChange(of: reorderEnabled) { _, val in
                        NotificationSettings.reorderReminderEnabled = val
                    }
            } header: {
                Text("용품")
            } footer: {
                Text("용품 재고가 설정한 기준 이하로 떨어지면 알림을 보냅니다.")
            }
        }
        .navigationTitle("알림 설정")
        .task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            notificationPermission = settings.authorizationStatus == .authorized
        }
    }

    private func saveRules() {
        ActivityReminderSettings.rules = rules
    }

    private func intervalLabel(_ minutes: Int) -> String {
        if minutes >= 1440 {
            return "\(minutes / 1440)일"
        } else if minutes >= 60 {
            let h = minutes / 60
            let m = minutes % 60
            return m == 0 ? "\(h)시간" : "\(h)시간 \(m)분"
        }
        return "\(minutes)분"
    }

    private func toggleVaccinationDay(_ day: Int) {
        if vaccinationDays.contains(day) {
            guard vaccinationDays.count > 1 else { return }
            vaccinationDays.removeAll { $0 == day }
        } else {
            vaccinationDays.append(day)
            vaccinationDays.sort(by: >)
        }
        NotificationSettings.vaccinationDaysBefore = vaccinationDays
    }

    private func vaccinationDayLabel(_ day: Int) -> String {
        switch day {
        case 0: "당일"
        case 1: "1일 전"
        default: "\(day)일 전"
        }
    }
}


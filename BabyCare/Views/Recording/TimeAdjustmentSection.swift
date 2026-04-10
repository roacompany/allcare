import SwiftUI

/// 모든 기록 뷰에서 재사용하는 시간 조정 섹션.
/// 탭하면 확장되어 시작/종료 시간을 자유롭게 조정 가능.
struct TimeAdjustmentSection: View {
    @Environment(ActivityViewModel.self) private var activityVM

    var accentColor: Color = .pink
    /// 종료 시간 입력을 표시할지 여부 (수유/수면처럼 duration이 있는 활동)
    var showEndTime: Bool = false

    @State private var isExpanded = false

    private var timeFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "a h:mm"
        f.locale = Locale(identifier: "ko_KR")
        return f
    }

    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "M/d (E)"
        f.locale = Locale(identifier: "ko_KR")
        return f
    }

    var body: some View {
        @Bindable var vm = activityVM

        VStack(spacing: 0) {
            // 요약 행 (항상 표시)
            Button {
                withAnimation(.spring(duration: 0.3)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "clock.fill")
                        .font(.subheadline)
                        .foregroundStyle(accentColor)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text("시작")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(formatTime(vm.manualStartTime))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(vm.isTimeAdjusted ? accentColor : .primary)
                        }

                        if showEndTime, let endTime = vm.manualEndTime {
                            HStack(spacing: 4) {
                                Text("종료")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(formatTime(endTime))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(accentColor)

                                if endTime > vm.manualStartTime {
                                    let dur = endTime.timeIntervalSince(vm.manualStartTime)
                                    Text("(\(dur.shortDuration))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

                    Spacer()

                    if vm.isTimeAdjusted {
                        Button {
                            vm.manualStartTime = Date()
                            vm.manualEndTime = nil
                            vm.isTimeAdjusted = false
                        } label: {
                            Text("초기화")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)

            // 확장 영역 (DatePicker)
            if isExpanded {
                Divider()
                    .padding(.horizontal, 14)

                VStack(spacing: 12) {
                    // 시작 시간
                    DatePicker(
                        "시작 시간",
                        selection: Binding(
                            get: { vm.manualStartTime },
                            set: { newValue in
                                // 미래 시점 차단 (DatePicker range는 표시 제한, set 시점에 실시간 클램프)
                                vm.manualStartTime = min(newValue, Date())
                                vm.isTimeAdjusted = true
                            }
                        ),
                        in: ...Date(),
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.compact)
                    .environment(\.locale, Locale(identifier: "ko_KR"))

                    // 종료 시간 (선택 가능한 경우)
                    if showEndTime {
                        // 종료 시간 토글
                        HStack {
                            Text("종료 시간")
                                .font(.subheadline)
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { vm.manualEndTime != nil },
                                set: {
                                    if $0 {
                                        // 시작 시간 이후인 현재 시각을 기본값으로 설정
                                        let now = Date()
                                        vm.manualEndTime = now > vm.manualStartTime ? now : vm.manualStartTime.addingTimeInterval(60)
                                        vm.isTimeAdjusted = true
                                    } else {
                                        vm.manualEndTime = nil
                                    }
                                }
                            ))
                            .labelsHidden()
                            .tint(accentColor)
                        }

                        if vm.manualEndTime != nil {
                            DatePicker(
                                "종료 시간",
                                selection: Binding(
                                    get: { vm.manualEndTime ?? Date() },
                                    set: { newValue in
                                        // 미래 시점 차단 + 시작 시간 이전 차단
                                        let clamped = min(max(newValue, vm.manualStartTime), Date())
                                        vm.manualEndTime = clamped
                                        vm.isTimeAdjusted = true
                                    }
                                ),
                                in: vm.manualStartTime...Date(),
                                displayedComponents: [.date, .hourAndMinute]
                            )
                            .datePickerStyle(.compact)
                            .environment(\.locale, Locale(identifier: "ko_KR"))
                        }
                    }

                    // 빠른 시간 버튼
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            quickTimeButton("지금", date: Date())
                            quickTimeButton("5분 전", date: Date().adding(minutes: -5))
                            quickTimeButton("15분 전", date: Date().adding(minutes: -15))
                            quickTimeButton("30분 전", date: Date().adding(minutes: -30))
                            quickTimeButton("1시간 전", date: Date().adding(hours: -1))
                            quickTimeButton("2시간 전", date: Date().adding(hours: -2))
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
        }
        .background(accentColor.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }

    // MARK: - Helpers

    private func formatTime(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return timeFormatter.string(from: date)
        }
        return "\(dateFormatter.string(from: date)) \(timeFormatter.string(from: date))"
    }

    private func quickTimeButton(_ label: String, date: Date) -> some View {
        Button(label) {
            activityVM.manualStartTime = date
            activityVM.isTimeAdjusted = label != "지금"
        }
        .font(.system(size: 13, weight: .medium))
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(accentColor.opacity(0.12))
        .foregroundStyle(accentColor)
        .clipShape(Capsule())
    }
}

// MARK: - Date Helper

private extension Date {
    func adding(minutes: Int) -> Date {
        Calendar.current.date(byAdding: .minute, value: minutes, to: self) ?? self
    }
}

import SwiftUI

// MARK: - Floating Timer Banner
// 진행 중인 활동 타이머를 메인 화면 어디서나 표시.
// 탭하면 해당 기록 시트 재오픈, 정지 버튼으로 즉시 종료.

struct FloatingTimerBanner: View {
    @Environment(ActivityViewModel.self) private var activityVM

    /// 탭 시 RecordingView를 다시 열기 위한 콜백
    var onResumeTap: (Activity.ActivityCategory) -> Void

    var body: some View {
        if activityVM.isTimerRunning, let type = activityVM.activeTimerType {
            HStack(spacing: 10) {
                Image(systemName: type.icon)
                    .font(.system(size: 14))
                    .foregroundStyle(.white)
                    .symbolEffect(.pulse, isActive: true)

                Text(type.displayName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(activityVM.elapsedTime.formattedDuration)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .monospacedDigit()
                    .contentTransition(.numericText())

                Spacer()

                Button {
                    _ = activityVM.stopTimer()
                    UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(bannerColor(for: type).gradient)
                    .shadow(color: bannerColor(for: type).opacity(0.3), radius: 8, y: 4)
            )
            .padding(.horizontal, 20)
            .contentShape(Capsule())
            .onTapGesture {
                onResumeTap(type.category)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.spring(duration: 0.3), value: activityVM.isTimerRunning)
        }
    }

    private func bannerColor(for type: Activity.ActivityType) -> Color {
        switch type {
        case .feedingBreast, .feedingBottle: return AppColors.feedingColor
        case .sleep: return AppColors.sleepColor
        default: return .pink
        }
    }
}

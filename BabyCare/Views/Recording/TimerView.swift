import SwiftUI
import UIKit

// MARK: - TimerView
// Reusable circular timer component. Reads / writes ActivityViewModel state.

struct TimerView: View {
    @Environment(ActivityViewModel.self) private var activityVM

    let type: Activity.ActivityType
    /// Accent colour for the ring and button.
    var accentColor: Color = .pink

    // Local animation state
    @State private var isPulsing = false
    @State private var stoppedDuration: TimeInterval = 0

    var body: some View {
        VStack(spacing: 24) {
            // ── Circular ring display ──────────────────────────────────────
            ZStack {
                // Background track
                Circle()
                    .stroke(accentColor.opacity(0.12), lineWidth: 10)
                    .frame(width: 180, height: 180)

                // Animated ring (only while running)
                if activityVM.isTimerRunning && activityVM.activeTimerType == type {
                    Circle()
                        .stroke(
                            AngularGradient(
                                colors: [accentColor.opacity(0.2), accentColor],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .frame(width: 180, height: 180)
                        .rotationEffect(.degrees(-90))
                        .rotationEffect(.degrees(isPulsing ? 360 : 0))
                        .animation(
                            .linear(duration: 4).repeatForever(autoreverses: false),
                            value: isPulsing
                        )
                }

                // Time label
                VStack(spacing: 4) {
                    Text(displayTime)
                        .font(.system(size: 44, weight: .bold, design: .monospaced))
                        .foregroundStyle(accentColor)
                        .contentTransition(.numericText())

                    if activityVM.isTimerRunning && activityVM.activeTimerType == type {
                        Text("기록 중")
                            .font(.caption)
                            .foregroundStyle(accentColor.opacity(0.7))
                    }
                }
            }
            .onAppear {
                if activityVM.isTimerRunning && activityVM.activeTimerType == type {
                    isPulsing = true
                }
            }

            // ── Start / Stop button ────────────────────────────────────────
            Button(action: toggleTimer) {
                HStack(spacing: 8) {
                    Image(systemName: isActiveTimer ? "stop.fill" : "play.fill")
                        .font(.system(size: 18, weight: .semibold))
                    Text(isActiveTimer ? "정지" : "시작")
                        .font(.system(size: 18, weight: .semibold))
                }
                .frame(width: 140, height: 50)
                .background(isActiveTimer ? accentColor : accentColor.opacity(0.15))
                .foregroundStyle(isActiveTimer ? .white : accentColor)
                .clipShape(Capsule())
                .shadow(color: isActiveTimer ? accentColor.opacity(0.35) : .clear, radius: 8, y: 4)
            }
            .animation(.spring(duration: 0.3), value: isActiveTimer)
        }
    }

    // MARK: - Helpers

    private var isActiveTimer: Bool {
        activityVM.isTimerRunning && activityVM.activeTimerType == type
    }

    private var displayTime: String {
        if isActiveTimer {
            return activityVM.elapsedTime.formattedDuration
        }
        if stoppedDuration > 0 {
            return stoppedDuration.formattedDuration
        }
        return "00:00"
    }

    private func toggleTimer() {
        if isActiveTimer {
            stoppedDuration = activityVM.stopTimer()
            isPulsing = false
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        } else {
            stoppedDuration = 0
            activityVM.startTimer(type: type)
            isPulsing = true
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        }
    }
}

#Preview {
    TimerView(type: .feedingBreast, accentColor: .pink)
        .environment(ActivityViewModel())
        .padding()
}

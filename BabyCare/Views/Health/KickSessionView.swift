import SwiftUI
import UIKit

struct KickSessionView: View {
    @Environment(PregnancyViewModel.self) private var pregnancyVM
    @Environment(AuthViewModel.self) private var authVM

    @State private var elapsedSeconds: Int = 0
    @State private var timer: Timer?

    private let targetCount = 10

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 면책 배너 (태동 관련)
                HStack(spacing: 10) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(.orange)
                    Text("태동 감소 또는 변화가 느껴지면 즉시 의료진에게 연락하세요. 이 기록은 참고용이며 의학적 판단을 대체하지 않습니다.")
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(.orange.opacity(0.4), lineWidth: 1))

                if let session = pregnancyVM.currentKickSession {
                    activeSessionView(session: session)
                } else {
                    startSessionView
                }

                if !pregnancyVM.kickSessions.isEmpty {
                    previousSessionsSection
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .navigationTitle("태동 기록")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            stopTimer()
        }
    }

    // MARK: - Start Session

    private var startSessionView: some View {
        VStack(spacing: 20) {
            Text("ACOG 기준: 2시간 내 10회 태동 목표")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                Task {
                    guard let userId = authVM.currentUserId else { return }
                    await pregnancyVM.startKickSession(userId: userId)
                    startTimer()
                }
            } label: {
                Circle()
                    .fill(AppColors.primaryAccent.opacity(0.15))
                    .frame(width: 160, height: 160)
                    .overlay(
                        VStack(spacing: 8) {
                            Image(systemName: "play.fill")
                                .font(.largeTitle)
                                .foregroundStyle(AppColors.primaryAccent)
                            Text("시작")
                                .font(.headline)
                                .foregroundStyle(AppColors.primaryAccent)
                        }
                    )
                    .overlay(
                        Circle()
                            .stroke(AppColors.primaryAccent.opacity(0.3), lineWidth: 2)
                    )
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Active Session

    private func activeSessionView(session: KickSession) -> some View {
        VStack(spacing: 20) {
            // 경과 시간
            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .foregroundStyle(.secondary)
                Text(formattedElapsed)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            // 카운터
            VStack(spacing: 4) {
                Text("\(session.kickCount)")
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundStyle(session.reachedTarget ? .green : AppColors.primaryAccent)
                Text("/ \(targetCount)회")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if session.reachedTarget {
                    Label("목표 달성!", systemImage: "star.fill")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.green)
                        .padding(.top, 4)
                }
            }

            // 탭 버튼 (88pt)
            Button {
                Task {
                    guard let userId = authVM.currentUserId else { return }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    await pregnancyVM.recordKick(userId: userId)
                    if pregnancyVM.currentKickSession?.reachedTarget == true {
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    }
                }
            } label: {
                Circle()
                    .fill(AppColors.primaryAccent.opacity(0.15))
                    .frame(width: 88, height: 88)
                    .overlay(
                        Image(systemName: "hand.tap.fill")
                            .font(.largeTitle)
                            .foregroundStyle(AppColors.primaryAccent)
                    )
                    .overlay(
                        Circle()
                            .stroke(AppColors.primaryAccent.opacity(0.4), lineWidth: 2)
                    )
            }
            .buttonStyle(.plain)

            Text("태동이 느껴질 때마다 탭하세요")
                .font(.caption)
                .foregroundStyle(.secondary)

            // 종료 버튼
            Button {
                Task {
                    guard let userId = authVM.currentUserId else { return }
                    await pregnancyVM.endKickSession(userId: userId)
                    stopTimer()
                }
            } label: {
                Text("세션 종료")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(.red.opacity(0.1), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Previous Sessions

    private var previousSessionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("이전 기록")
                .font(.headline)
                .padding(.horizontal, 4)

            ForEach(pregnancyVM.kickSessions.sorted(by: { $0.startedAt > $1.startedAt }).prefix(10)) { session in
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(session.startedAt, style: .date)
                            .font(.subheadline.weight(.medium))
                        Text(session.startedAt, style: .time)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "hand.tap.fill")
                                .font(.caption)
                                .foregroundStyle(session.reachedTarget ? .green : .secondary)
                            Text("\(session.kickCount)회")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(session.reachedTarget ? .green : .primary)
                        }
                        Text(formattedDuration(session.durationSeconds))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if session.reachedTarget {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
                .padding(12)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Helpers

    private var formattedElapsed: String {
        let hours = elapsedSeconds / 3600
        let minutes = (elapsedSeconds % 3600) / 60
        let seconds = elapsedSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func formattedDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d분 %02d초", mins, secs)
    }

    private func startTimer() {
        elapsedSeconds = 0
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                self.elapsedSeconds += 1
                // 2시간(7200초) 초과 시 자동 정지
                if self.elapsedSeconds >= 7200 {
                    self.stopTimer()
                }
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

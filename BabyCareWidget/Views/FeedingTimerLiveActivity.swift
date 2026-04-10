import ActivityKit
import SwiftUI
import WidgetKit

/// 수유 타이머 Live Activity UI
/// 잠금화면, Dynamic Island (compact / expanded / minimal) 지원
struct FeedingTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FeedingTimerAttributes.self) { context in
            // ── 잠금화면 배너 ──────────────────────────
            lockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded regions
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Image(systemName: context.attributes.feedingTypeIcon)
                            .font(.system(size: 20))
                            .foregroundStyle(.pink)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(context.attributes.feedingTypeDisplay)
                                .font(.caption2.bold())
                                .foregroundStyle(.primary)
                            Text(context.attributes.babyName)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(timerInterval: context.attributes.startTime...Date.distantFuture, countsDown: false)
                            .font(.system(size: 22, weight: .bold, design: .monospaced))
                            .foregroundStyle(.pink)
                            .monospacedDigit()
                            .multilineTextAlignment(.trailing)
                        Text("경과 시간")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        // Start time
                        Label(
                            DateFormatters.shortTime.string(from: context.attributes.startTime),
                            systemImage: "clock"
                        )
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        Spacer()
                        if context.state.isRunning {
                            Text("기록 중")
                                .font(.caption2.bold())
                                .foregroundStyle(.pink)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(.pink.opacity(0.15))
                                .clipShape(Capsule())
                        } else {
                            Text("완료")
                                .font(.caption2.bold())
                                .foregroundStyle(.green)
                        }
                    }
                    .padding(.top, 4)
                }
            } compactLeading: {
                // Compact leading (Dynamic Island pill 왼쪽)
                Image(systemName: context.attributes.feedingTypeIcon)
                    .font(.system(size: 12))
                    .foregroundStyle(.pink)
            } compactTrailing: {
                // Compact trailing (Dynamic Island pill 오른쪽)
                Text(timerInterval: context.attributes.startTime...Date.distantFuture, countsDown: false)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(.pink)
                    .monospacedDigit()
                    .frame(width: 50)
            } minimal: {
                // Minimal (다른 Live Activity와 공존 시)
                Image(systemName: context.attributes.feedingTypeIcon)
                    .font(.system(size: 12))
                    .foregroundStyle(.pink)
            }
        }
    }

    // MARK: - Lock Screen View

    @ViewBuilder
    private func lockScreenView(context: ActivityViewContext<FeedingTimerAttributes>) -> some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(.pink.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: context.attributes.feedingTypeIcon)
                    .font(.system(size: 20))
                    .foregroundStyle(.pink)
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(context.attributes.babyName)
                        .font(.subheadline.bold())
                    Text(context.attributes.feedingTypeDisplay)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("시작: \(DateFormatters.shortTime.string(from: context.attributes.startTime))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Timer
            VStack(alignment: .trailing, spacing: 2) {
                Text(timerInterval: context.attributes.startTime...Date.distantFuture, countsDown: false)
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundStyle(.pink)
                    .monospacedDigit()
                    .multilineTextAlignment(.trailing)

                if context.state.isRunning {
                    Text("기록 중")
                        .font(.caption2.bold())
                        .foregroundStyle(.pink)
                } else {
                    Text("완료")
                        .font(.caption2.bold())
                        .foregroundStyle(.green)
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
    }

    // MARK: - Helpers

    private func timerText(from seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }
}

/// DateFormatters 참조 (Widget Extension에서 접근용)
private enum DateFormatters {
    static let shortTime: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "a h:mm"
        return f
    }()
}

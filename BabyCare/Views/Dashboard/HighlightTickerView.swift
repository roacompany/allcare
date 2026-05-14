import SwiftUI
import Accessibility

// MARK: - HighlightTickerView

/// 주간 하이라이트 후보를 5초 간격으로 자동 순환하는 티커 뷰.
/// - reduceMotion=true 또는 후보 1개 이하: 정적 단일 카드 표시
/// - 후보 없음: EmptyView 반환
/// - 탭: 자동 롤링 일시정지 + selectedCandidate 전달
struct HighlightTickerView: View {

    // MARK: - Environment

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Properties

    let candidates: [InsightCandidate]
    var onCandidateSelected: ((InsightCandidate) -> Void)?

    // MARK: - State

    @State private var currentIndex: Int = 0
    @State private var isPaused: Bool = false

    // MARK: - Body

    var body: some View {
        if candidates.isEmpty {
            EmptyView()
        } else if reduceMotion || candidates.count <= 1 {
            staticCardView
        } else {
            animatedTickerView
        }
    }

    // MARK: - Static Card (reduceMotion or single candidate)

    @ViewBuilder
    private var staticCardView: some View {
        cardContent(for: candidates[0])
            .accessibilityIdentifier("weeklyHighlightTicker")
            .accessibilityElement(children: .combine)
    }

    // MARK: - Animated Ticker (TimelineView)

    @ViewBuilder
    private var animatedTickerView: some View {
        VStack(spacing: 8) {
            if isPaused {
                // 일시정지 상태: 정적 표시 (TimelineView 미사용)
                cardContent(for: candidates[currentIndex])
            } else {
                TimelineView(.periodic(from: .now, by: 5)) { context in
                    let computedIndex = tickIndex(for: context.date)
                    cardContent(for: candidates[computedIndex])
                        .onChange(of: computedIndex) { _, newIndex in
                            currentIndex = newIndex
                            announceCurrentCandidate(at: newIndex)
                        }
                }
            }
            progressDots
        }
        .accessibilityIdentifier("weeklyHighlightTicker")
        .accessibilityElement(children: .combine)
    }

    // MARK: - Card Content

    @ViewBuilder
    private func cardContent(for candidate: InsightCandidate) -> some View {
        HStack(spacing: 12) {
            Image(systemName: iconName(for: candidate.category))
                .font(.title3)
                .foregroundStyle(iconColor(for: candidate.category))
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(String(candidate.title.prefix(30)))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(candidate.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            changePercentBadge(for: candidate)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemGroupedBackground))
        )
        .contentShape(Rectangle())
        .onTapGesture {
            // CR-004: tap이 발생한 시점의 렌더된 후보(candidate)를 직접 캡처.
            // candidates[currentIndex] 사용 시 TimelineView tick 직후 탭 → displayed card와
            // sheet candidate 불일치 가능. 클로저 인자로 받은 candidate는 항상 렌더 중인 카드.
            isPaused.toggle()
            onCandidateSelected?(candidate)
        }
    }

    // MARK: - Change Percent Badge

    @ViewBuilder
    private func changePercentBadge(for candidate: InsightCandidate) -> some View {
        let pct = candidate.changePercent
        if abs(pct) >= 1 {
            Text("\(pct > 0 ? "↑" : "↓")\(Int(abs(pct).rounded()))%")
                .font(.caption.weight(.semibold))
                .foregroundStyle(pct > 0 ? Color.green : Color.red)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill((pct > 0 ? Color.green : Color.red).opacity(0.12))
                )
        }
    }

    // MARK: - Progress Dots

    @ViewBuilder
    private var progressDots: some View {
        HStack(spacing: 5) {
            ForEach(0..<candidates.count, id: \.self) { idx in
                Circle()
                    .fill(idx == currentIndex ? Color.primary : Color.secondary.opacity(0.4))
                    .frame(width: idx == currentIndex ? 7 : 5,
                           height: idx == currentIndex ? 7 : 5)
            }
        }
    }

    // MARK: - Helpers

    /// TimelineView context에서 현재 인덱스를 순환 계산합니다.
    /// Task 생성 없이 순수 연산만 수행합니다.
    private func tickIndex(for date: Date) -> Int {
        guard candidates.count > 1 else { return 0 }
        return Int(date.timeIntervalSinceReferenceDate / 5) % candidates.count
    }

    /// VoiceOver 공지 + Analytics highlightTickerShown 이벤트 전송.
    private func announceCurrentCandidate(at index: Int) {
        guard index < candidates.count else { return }
        let candidate = candidates[index]

        // VoiceOver accessibility 공지
        AccessibilityNotification.Announcement(candidate.title).post()

        // Analytics: metricKey / position 만 포함 (weekKey/babyId 금지)
        AnalyticsService.shared.trackEvent(
            AnalyticsEvents.highlightTickerShown,
            parameters: [
                AnalyticsParams.metricKey: candidate.metricKey,
                AnalyticsParams.position: String(index)
            ]
        )
    }

    // MARK: - Icon Helpers

    private func iconName(for category: InsightCategory) -> String {
        switch category {
        case .feeding: return "fork.knife"
        case .sleep:   return "moon.zzz.fill"
        case .diaper:  return "drop.fill"
        case .health:  return "heart.fill"
        }
    }

    private func iconColor(for category: InsightCategory) -> Color {
        switch category {
        case .feeding: return Color("feedingColor")
        case .sleep:   return Color("sleepColor")
        case .diaper:  return Color("diaperColor")
        case .health:  return Color.red
        }
    }
}

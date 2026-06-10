import SwiftUI
import Charts

// MARK: - HighlightDetailSheet

/// 주간 하이라이트 후보 상세 시트.
/// - 즉시 fallback 텍스트(candidate.detail) 표시, AI summary 도착 시 fade로 교체.
/// - Sparkline: LineMark + AreaMark (catmullRom, height 60).
/// - 200자 hard clamp, streaming 미사용 (일괄 표시).
/// - onAppear: highlightSheetOpened, onDisappear: highlightSheetDismissed.
struct HighlightDetailSheet: View {

    // MARK: - Inputs

    let candidate: InsightCandidate
    let sparkline: [Double]
    let aiSummary: String?

    // MARK: - State

    @State private var appearedAt: Date = .now
    @State private var displayedSummary: String?

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerSection
                    summarySection
                    sparklineSection
                    patternReportLink
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
        }
        .presentationDetents([.medium, .large])
        .accessibilityIdentifier("highlightDetailSheet")
        .onAppear {
            appearedAt = .now
            AnalyticsService.shared.trackEvent(
                AnalyticsEvents.highlightSheetOpened,
                parameters: [AnalyticsParams.metricKey: candidate.metricKey]
            )
        }
        .onDisappear {
            let dwellMs = Int(Date().timeIntervalSince(appearedAt) * 1000)
            AnalyticsService.shared.trackEvent(
                AnalyticsEvents.highlightSheetDismissed,
                parameters: [
                    AnalyticsParams.metricKey: candidate.metricKey,
                    AnalyticsParams.dwellMs: String(dwellMs)
                ]
            )
        }
        .onChange(of: aiSummary) { _, newValue in
            guard newValue != nil else { return }
            withAnimation(.easeInOut(duration: 0.25)) {
                displayedSummary = newValue
            }
        }
        .onAppear {
            // aiSummary가 이미 주입된 경우 즉시 반영
            if let summary = aiSummary {
                displayedSummary = summary
            }
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var headerSection: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName(for: candidate.category))
                .font(.title2)
                .foregroundStyle(iconColor(for: candidate.category))
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(iconColor(for: candidate.category).opacity(0.12))
                )

            Text(candidate.title)
                .font(.headline)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)

            Spacer()
        }
    }

    // MARK: - Summary

    @ViewBuilder
    private var summarySection: some View {
        let text: String = {
            if let summary = displayedSummary {
                return String(summary.prefix(200))
            }
            return candidate.detail
        }()

        Text(text)
            .font(.body)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .id(text) // 텍스트 변경 시 fade transition 트리거
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.25), value: text)
    }

    // MARK: - Sparkline

    @ViewBuilder
    private var sparklineSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("최근 추이")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            if sparkline.isEmpty {
                placeholderRect
            } else {
                sparklineChart
            }
        }
    }

    @ViewBuilder
    private var sparklineChart: some View {
        let indexedData = sparkline.enumerated().map { (index: $0.offset, value: $0.element) }

        Chart(indexedData, id: \.index) { item in
            AreaMark(
                x: .value("Week", item.index),
                y: .value("Value", item.value)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [iconColor(for: candidate.category).opacity(0.35), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .interpolationMethod(.catmullRom)

            LineMark(
                x: .value("Week", item.index),
                y: .value("Value", item.value)
            )
            .foregroundStyle(iconColor(for: candidate.category))
            .interpolationMethod(.catmullRom)
            .lineStyle(StrokeStyle(lineWidth: 2))
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .frame(height: 60)
    }

    @ViewBuilder
    private var placeholderRect: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color(.systemGray5))
            .frame(height: 60)
            .overlay(
                Text("데이터 없음")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            )
    }

    // MARK: - Pattern Report Link

    @ViewBuilder
    private var patternReportLink: some View {
        NavigationLink {
            PatternReportView()
        } label: {
            Label("더 보기", systemImage: "chart.bar.doc.horizontal")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGroupedBackground))
                )
        }
        .simultaneousGesture(TapGesture().onEnded {
            AnalyticsService.shared.trackEvent(
                AnalyticsEvents.highlightPatternReportTapped,
                parameters: [AnalyticsParams.metricKey: candidate.metricKey]
            )
        })
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

// MARK: - HighlightDetailSheetContainer (CR-002)

/// `HighlightDetailSheet` 의 비동기 AI summary fetch 래퍼.
/// Admin batch가 Firestore `highlightCache`에 미리 저장해둔 요약을 sheet 열릴 때 read.
/// 캐시 미존재/만료 시 nil → HighlightDetailSheet 내부에서 `candidate.detail` fallback.
struct HighlightDetailSheetContainer: View {

    let candidate: InsightCandidate
    let sparkline: [Double]
    let userId: String?
    let babyId: String?

    @State private var aiSummary: String?

    /// Service는 매번 새로 생성해도 비용이 거의 없음 (Firestore client는 내부 싱글톤 사용).
    private let aiService: HighlightAISummaryServiceProviding = HighlightAISummaryService()

    var body: some View {
        HighlightDetailSheet(
            candidate: candidate,
            sparkline: sparkline,
            aiSummary: aiSummary
        )
        .task(id: candidate.id) {
            guard let userId, let babyId else { return }
            let weekKey = WeeklyMetricSnapshot.weekKey(for: Date())
            do {
                aiSummary = try await aiService.fetchCachedSummary(
                    candidate: candidate,
                    weekKey: weekKey,
                    babyId: babyId,
                    userId: userId
                )
            } catch {
                aiSummary = nil
            }
        }
    }
}

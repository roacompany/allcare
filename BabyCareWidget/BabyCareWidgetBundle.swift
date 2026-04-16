import WidgetKit
import SwiftUI

@main
struct BabyCareWidgetBundle: WidgetBundle {
    var body: some Widget {
        // 기존 위젯
        BabyCareHomeWidget()
        BabyCareLockScreenWidget()
        FeedingTimerLiveActivity()

        // Phase 2 — 위젯 강화
        NextFeedingWidget()
        NextNapWidget()
        TodaySummaryWidget()
        GrowthPercentileWidget()

        // 임신 모드
        PregnancyDDayWidget()
    }
}

// MARK: - 홈 화면 위젯 (Small / Medium / Large)

struct BabyCareHomeWidget: Widget {
    let kind = "BabyCareWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BabyCareProvider()) { entry in
            HomeWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("올케어")
        .description("아기의 수유, 수면, 기저귀 현황을 한눈에")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

private struct HomeWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: BabyCareEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge:
            LargeWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

// MARK: - 잠금화면 위젯 (Circular / Rectangular / Inline)

struct BabyCareLockScreenWidget: Widget {
    let kind = "BabyCareLockScreenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BabyCareProvider()) { entry in
            LockScreenEntryView(entry: entry)
        }
        .configurationDisplayName("올케어 잠금화면")
        .description("잠금화면에서 수유 타이머와 요약 확인")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

private struct LockScreenEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: BabyCareEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            EnhancedLockScreenCircularView(entry: entry)
        case .accessoryRectangular:
            EnhancedLockScreenRectangularView(entry: entry)
        case .accessoryInline:
            EnhancedLockScreenInlineView(entry: entry)
        default:
            EnhancedLockScreenCircularView(entry: entry)
        }
    }
}

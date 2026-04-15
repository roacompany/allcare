import WidgetKit
import Foundation

struct BabyCareProvider: TimelineProvider {
    func placeholder(in context: Context) -> BabyCareEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (BabyCareEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BabyCareEntry>) -> Void) {
        let entry = makeEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func makeEntry() -> BabyCareEntry {
        BabyCareEntry(
            date: Date(),
            babyName: WidgetDataStore.babyName,
            babyAge: WidgetDataStore.babyAge,
            lastFeedingTime: WidgetDataStore.lastFeedingTime,
            lastFeedingType: WidgetDataStore.lastFeedingType,
            nextFeedingTime: WidgetDataStore.nextFeedingTime,
            lastSleepTime: WidgetDataStore.lastSleepTime,
            lastDiaperTime: WidgetDataStore.lastDiaperTime,
            todayFeedingCount: WidgetDataStore.todayFeedingCount,
            todaySleepMinutes: WidgetDataStore.todaySleepMinutes,
            todayDiaperCount: WidgetDataStore.todayDiaperCount,
            todayTotalMl: WidgetDataStore.todayTotalMl,
            recentActivities: WidgetDataStore.recentActivities,
            lastSleepDuration: WidgetDataStore.lastSleepDuration,
            feedingIntervalMinutes: WidgetDataStore.feedingIntervalMinutes,
            growthPercentile: WidgetDataStore.growthPercentile,
            napPrediction: WidgetDataStore.napPrediction
        )
    }
}

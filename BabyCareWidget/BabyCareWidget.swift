import WidgetKit
import SwiftUI

// MARK: - Timeline Provider

struct BabyCareProvider: TimelineProvider {
    func placeholder(in context: Context) -> BabyCareEntry {
        BabyCareEntry(
            date: Date(),
            babyName: "아기",
            babyAge: "100일",
            lastFeedingTime: Date().addingTimeInterval(-7200),
            lastFeedingType: "모유수유",
            nextFeedingTime: Date().addingTimeInterval(3600),
            lastSleepTime: Date().addingTimeInterval(-14400),
            lastDiaperTime: Date().addingTimeInterval(-3600)
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (BabyCareEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BabyCareEntry>) -> Void) {
        let entry = makeEntry()
        // 15분마다 갱신
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
            lastDiaperTime: WidgetDataStore.lastDiaperTime
        )
    }
}

// MARK: - Entry

struct BabyCareEntry: TimelineEntry {
    let date: Date
    let babyName: String
    let babyAge: String
    let lastFeedingTime: Date?
    let lastFeedingType: String?
    let nextFeedingTime: Date?
    let lastSleepTime: Date?
    let lastDiaperTime: Date?
}

// MARK: - Widget Views

struct BabyCareWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: BabyCareEntry

    var body: some View {
        switch family {
        case .systemSmall:
            smallWidget
        case .systemMedium:
            mediumWidget
        default:
            smallWidget
        }
    }

    // MARK: Small Widget

    private var smallWidget: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(entry.babyName)
                    .font(.headline)
                Spacer()
                Image(systemName: "heart.fill")
                    .foregroundStyle(.pink)
                    .font(.caption)
            }

            Spacer()

            if let lastFeeding = entry.lastFeedingTime {
                HStack(spacing: 4) {
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.caption2)
                        .foregroundStyle(.pink)
                    Text(timeAgo(lastFeeding))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if let nextFeeding = entry.nextFeedingTime {
                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .font(.caption2)
                        .foregroundStyle(nextFeeding < Date() ? .red : .blue)
                    Text(nextFeeding < Date() ? "수유 시간!" : timeUntil(nextFeeding))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(nextFeeding < Date() ? .red : .primary)
                }
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    // MARK: Medium Widget

    private var mediumWidget: some View {
        HStack(spacing: 16) {
            // Left: Baby info
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.babyName)
                    .font(.headline)
                if !entry.babyAge.isEmpty {
                    Text(entry.babyAge)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let next = entry.nextFeedingTime {
                    if next < Date() {
                        Text("수유 시간!")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.red)
                    } else {
                        Text("다음 수유")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(timeUntil(next))
                            .font(.subheadline.weight(.medium))
                    }
                }
            }

            Divider()

            // Right: Activity summary
            VStack(alignment: .leading, spacing: 8) {
                activityRow(icon: "cup.and.saucer.fill", color: .pink,
                           label: entry.lastFeedingType ?? "수유",
                           time: entry.lastFeedingTime)
                activityRow(icon: "moon.zzz.fill", color: .indigo,
                           label: "수면",
                           time: entry.lastSleepTime)
                activityRow(icon: "humidity.fill", color: .orange,
                           label: "기저귀",
                           time: entry.lastDiaperTime)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private func activityRow(icon: String, color: Color, label: String, time: Date?) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 0) {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(time.map { timeAgo($0) } ?? "-")
                    .font(.caption.weight(.medium))
            }
        }
    }

    // MARK: Helpers

    private func timeAgo(_ date: Date) -> String {
        let minutes = Int(Date().timeIntervalSince(date) / 60)
        if minutes < 1 { return "방금" }
        if minutes < 60 { return "\(minutes)분 전" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)시간 전" }
        return "\(hours / 24)일 전"
    }

    private func timeUntil(_ date: Date) -> String {
        let minutes = Int(date.timeIntervalSince(Date()) / 60)
        if minutes < 1 { return "곧" }
        if minutes < 60 { return "\(minutes)분 후" }
        let hours = minutes / 60
        return "\(hours)시간 \(minutes % 60)분 후"
    }
}

// MARK: - Widget Configuration

struct BabyCareWidget: Widget {
    let kind = "BabyCareWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BabyCareProvider()) { entry in
            BabyCareWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("올케어")
        .description("아기의 수유, 수면, 기저귀 현황을 한눈에")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Widget Bundle

@main
struct BabyCareWidgetBundle: WidgetBundle {
    var body: some Widget {
        BabyCareWidget()
    }
}

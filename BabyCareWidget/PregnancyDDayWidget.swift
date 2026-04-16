import WidgetKit
import SwiftUI

// MARK: - Entry

struct PregnancyDDayEntry: TimelineEntry {
    let date: Date
    let babyNickname: String
    let currentWeek: Int
    let currentDay: Int
    let dDay: Int
    let isActive: Bool

    var weekText: String {
        guard isActive else { return "" }
        return "\(currentWeek)주 \(currentDay)일"
    }

    var dDayText: String {
        guard isActive else { return "" }
        if dDay > 0 { return "D-\(dDay)" }
        if dDay == 0 { return "D-Day" }
        return "D+\(abs(dDay))"
    }

    var progress: Double {
        guard isActive, currentWeek > 0 else { return 0 }
        return min(Double(currentWeek) / 40.0, 1.0)
    }

    static let placeholder = PregnancyDDayEntry(
        date: Date(),
        babyNickname: "우리 아기",
        currentWeek: 20,
        currentDay: 3,
        dDay: 140,
        isActive: true
    )

    static let inactive = PregnancyDDayEntry(
        date: Date(),
        babyNickname: "",
        currentWeek: 0,
        currentDay: 0,
        dDay: 0,
        isActive: false
    )
}

// MARK: - Provider

struct PregnancyDDayProvider: TimelineProvider {
    func placeholder(in context: Context) -> PregnancyDDayEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (PregnancyDDayEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PregnancyDDayEntry>) -> Void) {
        let entry = makeEntry()
        // 일 단위 갱신 — 다음 자정.
        let tomorrow = Calendar.current.startOfDay(for: Date().addingTimeInterval(86400))
        let timeline = Timeline(entries: [entry], policy: .after(tomorrow))
        completion(timeline)
    }

    private func makeEntry() -> PregnancyDDayEntry {
        guard PregnancyWidgetDataStore.isActive else {
            return .inactive
        }
        return PregnancyDDayEntry(
            date: Date(),
            babyNickname: PregnancyWidgetDataStore.babyNickname,
            currentWeek: PregnancyWidgetDataStore.currentWeek,
            currentDay: PregnancyWidgetDataStore.currentDay,
            dDay: PregnancyWidgetDataStore.dDay,
            isActive: true
        )
    }
}

// MARK: - Widget

struct PregnancyDDayWidget: Widget {
    let kind = "PregnancyDDayWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PregnancyDDayProvider()) { entry in
            PregnancyDDayWidgetView(entry: entry)
        }
        .configurationDisplayName(NSLocalizedString("pregnancy.widget.dday.title", comment: ""))
        .description(NSLocalizedString("pregnancy.widget.dday.description", comment: ""))
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular])
    }
}

// MARK: - Views

struct PregnancyDDayWidgetView: View {
    let entry: PregnancyDDayEntry
    @Environment(\.widgetFamily) var family
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        switch family {
        case .systemMedium:
            mediumView
        case .accessoryCircular:
            circularView
        default:
            smallView
        }
    }

    // MARK: Small

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "heart.fill")
                    .font(.caption2)
                    .foregroundStyle(WidgetColors.feeding(colorScheme))
                Text(NSLocalizedString("pregnancy.widget.label", comment: ""))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Spacer()

            if entry.isActive {
                Text(entry.dDayText)
                    .font(.title.weight(.bold).monospacedDigit())
                    .foregroundStyle(WidgetColors.feedingText(colorScheme))
                    .minimumScaleFactor(0.7)

                Text(entry.weekText)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                Text(entry.babyNickname)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            } else {
                Text(NSLocalizedString("pregnancy.widget.inactive", comment: ""))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .containerBackground(for: .widget) {
            ContainerRelativeShape()
                .fill(WidgetGradient.background(colorScheme))
        }
        .widgetURL(URL(string: "babycare://pregnancy"))
    }

    // MARK: Medium

    private var mediumView: some View {
        HStack(spacing: 16) {
            // Left: D-day
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(WidgetColors.feeding(colorScheme))
                    Text(NSLocalizedString("pregnancy.widget.label", comment: ""))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if entry.isActive {
                    Text(entry.dDayText)
                        .font(.title.weight(.bold).monospacedDigit())
                        .foregroundStyle(WidgetColors.feedingText(colorScheme))
                        .minimumScaleFactor(0.7)

                    Text(entry.weekText)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(entry.babyNickname)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                } else {
                    Text(NSLocalizedString("pregnancy.widget.inactive", comment: ""))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()
                .overlay(WidgetColors.divider(colorScheme))

            // Right: 진행도
            if entry.isActive {
                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("pregnancy.widget.progress", comment: ""))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Gauge(value: entry.progress) {
                        EmptyView()
                    } currentValueLabel: {
                        Text("\(Int(entry.progress * 100))%")
                            .font(.caption2.weight(.bold))
                    }
                    .gaugeStyle(.linearCapacity)
                    .tint(WidgetColors.feeding(colorScheme))

                    Text(String(
                        format: NSLocalizedString("pregnancy.widget.weeksLeft", comment: ""),
                        max(0, 40 - entry.currentWeek)
                    ))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                }
            }
        }
        .containerBackground(for: .widget) {
            ContainerRelativeShape()
                .fill(WidgetGradient.background(colorScheme))
        }
        .widgetURL(URL(string: "babycare://pregnancy"))
    }

    // MARK: Lock Screen Circular

    @ViewBuilder
    private var circularView: some View {
        if entry.isActive {
            Gauge(value: entry.progress) {
                Image(systemName: "heart.fill")
            } currentValueLabel: {
                Text("\(entry.currentWeek)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .tint(.pink)
            .widgetURL(URL(string: "babycare://pregnancy"))
        } else {
            Gauge(value: 0.0) {
                Image(systemName: "heart")
            } currentValueLabel: {
                Image(systemName: "minus")
                    .font(.system(size: 10, weight: .bold))
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .tint(.gray)
        }
    }
}

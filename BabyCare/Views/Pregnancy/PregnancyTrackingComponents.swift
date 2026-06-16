import SwiftUI

/// ②기록 허브 세그먼트.
enum TrackingSegment: String, CaseIterable, Identifiable {
    case daily = "매일 도구"
    case conditional = "상태별"
    case optional = "선택 모듈"
    var id: String { rawValue }
}

/// 오늘 기록 개수 칩 스트립.
struct TodaySummaryStrip: View {
    let summary: PregnancyTrackingSummary
    var body: some View {
        if summary.isEmpty {
            Text("오늘 첫 기록을 남겨보세요")
                .font(DS2.Font.caption).foregroundStyle(DS2.Color.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack(spacing: DS2.Spacing.sm) {
                if summary.kickCount > 0 { chip("태동 \(summary.kickCount)회") }
                if summary.weightCount > 0 { chip("체중 \(summary.weightCount)") }
                if summary.symptomCount > 0 { chip("증상 \(summary.symptomCount)") }
                Spacer(minLength: 0)
            }
        }
    }
    private func chip(_ text: String) -> some View {
        Text(text).font(DS2.Font.caption)
            .padding(.horizontal, DS2.Spacing.sm).padding(.vertical, DS2.Spacing.xs)
            .background(DS2.Color.tintPurple.opacity(0.5), in: Capsule())
            .foregroundStyle(DS2.Color.pregnancy)
    }
}

/// 도구 카드(아이콘+제목+서브타이틀+미니 슬롯). 탭 시 action.
struct TrackingToolCard<Accessory: View>: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void
    @ViewBuilder var accessory: () -> Accessory

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS2.Spacing.md) {
                Image(systemName: icon).font(.title2).foregroundStyle(DS2.Color.pregnancy)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: DS2.Spacing.xs) {
                    Text(title).font(DS2.Font.headline).foregroundStyle(DS2.Color.textPrimary)
                    Text(subtitle).font(DS2.Font.caption).foregroundStyle(DS2.Color.textSecondary)
                }
                Spacer(minLength: 0)
                accessory()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
            .padding(DS2.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: DS2.Radius.md))
        }
        .buttonStyle(.plain)
    }
}

extension TrackingToolCard where Accessory == EmptyView {
    init(icon: String, title: String, subtitle: String, action: @escaping () -> Void) {
        self.init(icon: icon, title: title, subtitle: subtitle, action: action, accessory: { EmptyView() })
    }
}

/// 선택 모듈(약/수분/수면) 표시 토글 카드. 꺼지면 흐림 + "켜기" 안내.
/// 표시 상태는 로컬 선호(@AppStorage) — Firestore 불필요.
struct OptionalModuleToggleCard: View {
    let icon: String
    let title: String
    let subtitle: String
    @Binding var isEnabled: Bool

    var body: some View {
        DS2Card(tint: isEnabled ? DS2.Color.pregnancy : nil) {
            HStack(spacing: DS2.Spacing.md) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(isEnabled ? DS2.Color.pregnancy : DS2.Color.textSecondary)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: DS2.Spacing.xs) {
                    Text(title)
                        .font(DS2.Font.headline)
                        .foregroundStyle(isEnabled ? DS2.Color.textPrimary : DS2.Color.textSecondary)
                    Text(isEnabled ? subtitle : "켜면 \(title) 기록을 추가할 수 있어요")
                        .font(DS2.Font.caption)
                        .foregroundStyle(DS2.Color.textSecondary)
                }
                Spacer(minLength: 0)
                Toggle("표시", isOn: $isEnabled)
                    .labelsHidden()
                    .tint(DS2.Color.pregnancy)
            }
            .opacity(isEnabled ? 1 : 0.6)
        }
    }
}

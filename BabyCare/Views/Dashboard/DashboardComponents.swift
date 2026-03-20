import SwiftUI

// MARK: - Dashboard Alert Banner

struct DashboardAlertBanner: View {
    let icon: String
    let message: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(message)
                .font(.caption.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Quick Action Button

struct QuickActionButton: View {
    let type: Activity.ActivityType
    let action: () async -> Void

    @State private var isPressed = false

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            Task { await action() }
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(type.color).opacity(0.15))
                        .frame(height: 52)
                    Image(systemName: type.icon)
                        .font(.title3)
                        .foregroundStyle(Color(type.color))
                        .accessibilityHidden(true)
                }
                Text(type.displayName)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(type.displayName) 빠른 기록")
        .scaleEffect(isPressed ? 0.93 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Timeline Row

struct TimelineRow: View {
    let activity: Activity

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(activity.type.color).opacity(0.18))
                    .frame(width: 40, height: 40)
                Image(systemName: activity.type.icon)
                    .font(.body)
                    .foregroundStyle(Color(activity.type.color))
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(activity.type.displayName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)

                HStack(spacing: 6) {
                    if let durationText = activity.durationText {
                        Text(durationText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let amountText = activity.amountText {
                        Text(amountText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let note = activity.note, !note.isEmpty {
                        Text(note)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            Text(activity.startTime.timeAgo())
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel({
            var parts = [activity.type.displayName]
            if let durationText = activity.durationText { parts.append(durationText) }
            if let amountText = activity.amountText { parts.append(amountText) }
            parts.append(activity.startTime.timeAgo())
            return parts.joined(separator: ", ")
        }())
    }
}

import SwiftUI

struct AnnouncementBanner: View {
    @Environment(AnnouncementViewModel.self) private var announcementVM

    var body: some View {
        if let latest = announcementVM.announcements.first, !announcementVM.isRead(latest) {
            NavigationLink {
                AnnouncementListView()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: iconName(for: latest.priority))
                        .foregroundStyle(color(for: latest.priority))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(latest.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        if announcementVM.unreadCount > 1 {
                            Text("외 \(announcementVM.unreadCount - 1)건의 공지")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(color(for: latest.priority).opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private func iconName(for priority: Announcement.Priority) -> String {
        switch priority {
        case .urgent: return "exclamationmark.triangle.fill"
        case .high: return "megaphone.fill"
        case .normal: return "bell.fill"
        case .low: return "info.circle.fill"
        }
    }

    private func color(for priority: Announcement.Priority) -> Color {
        switch priority {
        case .urgent: return .red
        case .high: return .orange
        case .normal: return .blue
        case .low: return .gray
        }
    }
}

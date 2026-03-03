import SwiftUI

struct AnnouncementListView: View {
    @Environment(AnnouncementViewModel.self) private var announcementVM

    var body: some View {
        List {
            if announcementVM.announcements.isEmpty {
                ContentUnavailableView(
                    "공지사항이 없습니다",
                    systemImage: "megaphone",
                    description: Text("새로운 공지가 등록되면 여기에 표시됩니다.")
                )
            } else {
                ForEach(announcementVM.announcements) { announcement in
                    AnnouncementRow(
                        announcement: announcement,
                        isRead: announcementVM.isRead(announcement)
                    )
                    .onAppear {
                        announcementVM.markAsRead(announcement)
                    }
                }
            }
        }
        .navigationTitle("공지사항")
        .refreshable {
            await announcementVM.loadAnnouncements()
        }
        .task {
            if announcementVM.announcements.isEmpty {
                await announcementVM.loadAnnouncements()
            }
        }
    }
}

private struct AnnouncementRow: View {
    let announcement: Announcement
    let isRead: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                if !isRead {
                    Circle()
                        .fill(.blue)
                        .frame(width: 8, height: 8)
                }

                priorityBadge

                Text(announcement.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isRead ? .secondary : .primary)
                    .lineLimit(2)
            }

            Text(announcement.content)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)

            Text(announcement.createdAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var priorityBadge: some View {
        switch announcement.priority {
        case .urgent:
            Text("긴급")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(.red))
        case .high:
            Text("중요")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(.orange))
        case .normal, .low:
            EmptyView()
        }
    }
}

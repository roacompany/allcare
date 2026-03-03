import SwiftUI

struct AdminAnnouncementListView: View {
    @Environment(AnnouncementViewModel.self) private var announcementVM
    @State private var filter: AnnouncementFilter = .all
    @State private var showEditor = false

    enum AnnouncementFilter: String, CaseIterable {
        case all = "전체"
        case active = "활성"
        case inactive = "비활성"
    }

    private var filtered: [Announcement] {
        switch filter {
        case .all: return announcementVM.allAnnouncements
        case .active: return announcementVM.allAnnouncements.filter(\.isActive)
        case .inactive: return announcementVM.allAnnouncements.filter { !$0.isActive }
        }
    }

    var body: some View {
        List {
            Picker("필터", selection: $filter) {
                ForEach(AnnouncementFilter.allCases, id: \.self) { f in
                    Text(f.rawValue).tag(f)
                }
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())

            if announcementVM.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else if filtered.isEmpty {
                ContentUnavailableView("공지사항 없음", systemImage: "megaphone")
            } else {
                ForEach(filtered) { announcement in
                    NavigationLink {
                        AdminAnnouncementEditView(announcement: announcement)
                    } label: {
                        AnnouncementRow(announcement: announcement)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            Task { await announcementVM.deleteAnnouncement(announcement) }
                        } label: {
                            Label("삭제", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            Task { await announcementVM.toggleActive(announcement) }
                        } label: {
                            Label(
                                announcement.isActive ? "비활성화" : "활성화",
                                systemImage: announcement.isActive ? "eye.slash" : "eye"
                            )
                        }
                        .tint(announcement.isActive ? .orange : .green)
                    }
                }
            }
        }
        .navigationTitle("공지사항 관리")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showEditor = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showEditor) {
            NavigationStack {
                AdminAnnouncementEditView(announcement: nil)
            }
        }
        .task {
            await announcementVM.loadAllAnnouncements()
        }
    }
}

private struct AnnouncementRow: View {
    let announcement: Announcement

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                PriorityBadge(priority: announcement.priority)
                Text(announcement.title)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                Spacer()
                if !announcement.isActive {
                    Text("비활성")
                        .font(.caption2)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(.gray))
                }
            }
            Text(announcement.content)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Text(announcement.createdAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }
}

private struct PriorityBadge: View {
    let priority: Announcement.Priority

    var body: some View {
        Text(label)
            .font(.caption2.bold())
            .foregroundStyle(.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(RoundedRectangle(cornerRadius: 4).fill(color))
    }

    private var label: String {
        switch priority {
        case .low: "낮음"
        case .normal: "보통"
        case .high: "높음"
        case .urgent: "긴급"
        }
    }

    private var color: Color {
        switch priority {
        case .low: .gray
        case .normal: .blue
        case .high: .orange
        case .urgent: .red
        }
    }
}

import SwiftUI

struct AdminDashboardView: View {
    @Environment(AnnouncementViewModel.self) private var announcementVM
    @State private var adminVM = AdminDashboardViewModel()

    var body: some View {
        List {
            Section("통계") {
                HStack {
                    StatCard(title: "총 사용자", value: adminVM.userCount.map(String.init) ?? "-", icon: "person.2.fill", color: .blue)
                    StatCard(title: "총 공지", value: "\(announcementVM.allAnnouncements.count)", icon: "megaphone.fill", color: .orange)
                    StatCard(title: "활성 공지", value: "\(announcementVM.allAnnouncements.filter(\.isActive).count)", icon: "checkmark.circle.fill", color: .green)
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            Section("관리") {
                NavigationLink {
                    AdminAnnouncementListView()
                } label: {
                    Label("공지사항 관리", systemImage: "megaphone.fill")
                }

                NavigationLink {
                    AdminPushView()
                } label: {
                    Label("푸시 발송", systemImage: "bell.badge.fill")
                }
            }
        }
        .navigationTitle("관리자 패널")
        .task {
            await announcementVM.loadAllAnnouncements()
            await adminVM.loadUserCount()
        }
    }
}

private struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            Text(value)
                .font(.title2.bold())
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
}

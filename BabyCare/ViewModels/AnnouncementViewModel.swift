import Foundation

@MainActor @Observable
final class AnnouncementViewModel {
    var announcements: [Announcement] = []
    var isLoading = false
    var errorMessage: String?

    private let firestoreService = FirestoreService.shared
    private let readKey = "readAnnouncementIds"

    // MARK: - Computed

    var hasUnread: Bool { unreadCount > 0 }

    var unreadCount: Int {
        let readIds = readAnnouncementIds
        return announcements.filter { announcement in
            guard let id = announcement.id else { return false }
            return !readIds.contains(id)
        }.count
    }

    // MARK: - Actions

    func loadAnnouncements() async {
        isLoading = true
        do {
            announcements = try await firestoreService.fetchActiveAnnouncements()
        } catch {
            errorMessage = "공지사항을 불러올 수 없습니다"
        }
        isLoading = false
    }

    func markAsRead(_ announcement: Announcement) {
        guard let id = announcement.id else { return }
        var ids = readAnnouncementIds
        ids.insert(id)
        UserDefaults.standard.set(Array(ids), forKey: readKey)
    }

    func markAllAsRead() {
        let ids = Set(announcements.compactMap(\.id))
        UserDefaults.standard.set(Array(ids), forKey: readKey)
    }

    func isRead(_ announcement: Announcement) -> Bool {
        guard let id = announcement.id else { return true }
        return readAnnouncementIds.contains(id)
    }

    // MARK: - Admin

    var allAnnouncements: [Announcement] = []

    func loadAllAnnouncements() async {
        isLoading = true
        do {
            allAnnouncements = try await firestoreService.fetchAllAnnouncements()
        } catch {
            errorMessage = "공지사항 목록을 불러올 수 없습니다"
        }
        isLoading = false
    }

    func createAnnouncement(title: String, content: String, priority: Announcement.Priority) async {
        let announcement = Announcement(
            title: title,
            content: content,
            createdAt: Date(),
            isActive: true,
            priority: priority
        )
        do {
            try await firestoreService.saveAnnouncement(announcement)
            await loadAllAnnouncements()
        } catch {
            errorMessage = "공지사항 등록에 실패했습니다"
        }
    }

    func updateAnnouncement(_ announcement: Announcement) async {
        do {
            try await firestoreService.saveAnnouncement(announcement)
            await loadAllAnnouncements()
        } catch {
            errorMessage = "공지사항 수정에 실패했습니다"
        }
    }

    func deleteAnnouncement(_ announcement: Announcement) async {
        guard let id = announcement.id else { return }
        do {
            try await firestoreService.deleteAnnouncement(id)
            await loadAllAnnouncements()
        } catch {
            errorMessage = "공지사항 삭제에 실패했습니다"
        }
    }

    func toggleActive(_ announcement: Announcement) async {
        var updated = announcement
        updated.isActive.toggle()
        await updateAnnouncement(updated)
    }

    // MARK: - Private

    private var readAnnouncementIds: Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: readKey) ?? [])
    }
}

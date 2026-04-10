import FirebaseFirestore
import Foundation
import UIKit

@MainActor @Observable
final class DiaryViewModel {
    var entries: [DiaryEntry] = []
    var isLoading = false
    var isLoadingMore = false
    var hasMorePages = true
    var errorMessage: String?
    var showAddEntry = false

    nonisolated(unsafe) private var lastDocument: DocumentSnapshot?

    // Form
    var content = ""
    var selectedMood: DiaryEntry.Mood?
    var selectedPhotos: [UIImage] = []
    var entryDate = Date()
    var editingEntry: DiaryEntry?
    var existingPhotoURLs: [String] = []

    private let firestoreService = FirestoreService.shared
    private let storageService = StorageService.shared

    // MARK: - Validation

    var isFormValid: Bool {
        !content.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - CRUD

    func loadEntries(userId: String, babyId: String) async {
        isLoading = true
        lastDocument = nil
        hasMorePages = true
        defer { isLoading = false }
        do {
            let result = try await firestoreService.fetchDiaryEntries(
                userId: userId, babyId: babyId, limit: 20, after: nil
            )
            entries = result.entries
            lastDocument = result.lastDocument
            hasMorePages = result.lastDocument != nil
        } catch {
            errorMessage = "일기를 불러오지 못했습니다: \(error.localizedDescription)"
        }
    }

    func loadMoreEntries(userId: String, babyId: String) async {
        guard hasMorePages, !isLoadingMore, !isLoading else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let result = try await firestoreService.fetchDiaryEntries(
                userId: userId, babyId: babyId, limit: 20, after: lastDocument
            )
            entries.append(contentsOf: result.entries)
            lastDocument = result.lastDocument
            hasMorePages = result.lastDocument != nil
        } catch {
            errorMessage = "일기를 더 불러오지 못했습니다: \(error.localizedDescription)"
        }
    }

    func startEditing(_ entry: DiaryEntry) {
        editingEntry = entry
        content = entry.content
        selectedMood = entry.mood
        entryDate = entry.date
        selectedPhotos = []
        existingPhotoURLs = entry.photoURLs
    }

    func addEntry(userId: String, babyId: String) async {
        guard isFormValid else {
            errorMessage = "내용을 입력해주세요."
            return
        }

        isLoading = true
        defer { isLoading = false }

        if let existing = editingEntry {
            // 수정 모드
            var updated = existing
            updated.content = content.trimmingCharacters(in: .whitespaces)
            updated.mood = selectedMood
            updated.date = entryDate
            updated.updatedAt = Date()

            do {
                // Upload newly added photos and merge with kept existing URLs
                var newPhotoURLs: [String] = []
                for (index, photo) in selectedPhotos.enumerated() {
                    let url = try await storageService.uploadDiaryPhoto(
                        photo, userId: userId, babyId: babyId,
                        diaryId: existing.id, index: existingPhotoURLs.count + index
                    )
                    newPhotoURLs.append(url)
                }
                updated.photoURLs = existingPhotoURLs + newPhotoURLs

                try await firestoreService.saveDiaryEntry(updated, userId: userId)
                if let idx = entries.firstIndex(where: { $0.id == updated.id }) {
                    entries[idx] = updated
                }
                resetForm()
                showAddEntry = false
            } catch {
                errorMessage = "일기 수정에 실패했습니다: \(error.localizedDescription)"
            }
        } else {
            // 신규 생성
            var entry = DiaryEntry(
                babyId: babyId,
                date: entryDate,
                content: content.trimmingCharacters(in: .whitespaces),
                mood: selectedMood
            )

            do {
                var photoURLs: [String] = []
                for (index, photo) in selectedPhotos.enumerated() {
                    let url = try await storageService.uploadDiaryPhoto(
                        photo, userId: userId, babyId: babyId,
                        diaryId: entry.id, index: index
                    )
                    photoURLs.append(url)
                }
                entry.photoURLs = photoURLs

                try await firestoreService.saveDiaryEntry(entry, userId: userId)
                entries.insert(entry, at: 0)
                resetForm()
                showAddEntry = false
            } catch {
                errorMessage = "일기 저장에 실패했습니다: \(error.localizedDescription)"
            }
        }
    }

    func deleteEntry(_ entry: DiaryEntry, userId: String, babyId: String) async {
        do {
            try await firestoreService.deleteDiaryEntry(entry, userId: userId)
            entries.removeAll { $0.id == entry.id }
        } catch {
            errorMessage = "일기 삭제에 실패했습니다: \(error.localizedDescription)"
        }
    }

    func resetForm() {
        content = ""
        selectedMood = nil
        selectedPhotos = []
        existingPhotoURLs = []
        entryDate = Date()
        editingEntry = nil
        errorMessage = nil
    }
}

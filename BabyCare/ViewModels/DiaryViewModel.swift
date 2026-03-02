import Foundation
import UIKit

@MainActor @Observable
final class DiaryViewModel {
    var entries: [DiaryEntry] = []
    var isLoading = false
    var errorMessage: String?
    var showAddEntry = false

    // Form
    var content = ""
    var selectedMood: DiaryEntry.Mood?
    var selectedPhotos: [UIImage] = []
    var entryDate = Date()

    private let firestoreService = FirestoreService.shared
    private let storageService = StorageService.shared

    func loadEntries(userId: String, babyId: String) async {
        isLoading = true
        do {
            entries = try await firestoreService.fetchDiaryEntries(userId: userId, babyId: babyId)
        } catch {
            errorMessage = "일기를 불러오지 못했습니다."
        }
        isLoading = false
    }

    func addEntry(userId: String, babyId: String) async {
        guard !content.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "내용을 입력해주세요."
            return
        }

        isLoading = true
        var entry = DiaryEntry(
            babyId: babyId,
            date: entryDate,
            content: content.trimmingCharacters(in: .whitespaces),
            mood: selectedMood
        )

        do {
            // Upload photos
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
            errorMessage = "일기 저장에 실패했습니다."
        }
        isLoading = false
    }

    func resetForm() {
        content = ""
        selectedMood = nil
        selectedPhotos = []
        entryDate = Date()
        errorMessage = nil
    }
}

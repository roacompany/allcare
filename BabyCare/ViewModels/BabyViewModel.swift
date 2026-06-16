import Foundation
import UIKit

@MainActor @Observable
final class BabyViewModel {
    var babies: [Baby] = []
    var selectedBaby: Baby?
    var isLoading = true
    private(set) var hasInitialLoad = false
    var errorMessage: String?
    var showAddBaby = false

    // Form fields
    var babyName = ""
    var babyBirthDate = Date()
    var babyGender: Baby.Gender = .male
    var babyBloodType: Baby.BloodType?
    var babyPhoto: UIImage?

    private let firestoreService = FirestoreService.shared
    private let storageService: StorageServiceProviding

    init(storageService: StorageServiceProviding = StorageService.shared) {
        self.storageService = storageService
    }

    // MARK: - Data User Resolution

    /// Returns the userId whose Firestore path should be used for data loading/saving.
    /// For shared babies this is the owner's userId; for own babies it falls back to the current user.
    func dataUserId(currentUserId: String?) -> String? {
        selectedBaby?.ownerUserId ?? currentUserId
    }

    /// Resolves the data userId for the selected baby.
    /// Returns nil if no authenticated user.
    func resolvedUserId(auth: AuthViewModel) -> String? {
        guard let currentUserId = auth.currentUserId else { return nil }
        return dataUserId(currentUserId: currentUserId) ?? currentUserId
    }

    // MARK: - Account Switch Reset

    /// 로그아웃/계정 전환 시 사용자 데이터 초기화 (계정 간 잔존 방지).
    func reset() {
        babies = []
        selectedBaby = nil
        hasInitialLoad = false
        errorMessage = nil
        resetForm()
    }

    /// 새 목록 기준 선택 아기 재검증 — 현재 선택이 목록에 없으면 첫 아기로(계정 전환 stale 선택 방지).
    static func resolveSelection(current: Baby?, in babies: [Baby]) -> Baby? {
        if let current, babies.contains(where: { $0.id == current.id }) { return current }
        return babies.first
    }

    // MARK: - Validation

    var isFormValid: Bool {
        !babyName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - CRUD

    func loadBabies(userId: String) async {
        // UI 테스트 모드: 즉시 목 데이터 사용 (또는 UI_TESTING_NO_BABY 시 empty state)
        if CommandLine.arguments.contains("UI_TESTING") {
            hasInitialLoad = true
            isLoading = false
            if CommandLine.arguments.contains("UI_TESTING_NO_BABY") {
                babies = []
                selectedBaby = nil
            } else {
                let mockBaby = Baby(
                    id: "mock-baby-id",
                    name: "테스트 아기",
                    birthDate: Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date(),
                    gender: .female
                )
                babies = [mockBaby]
                selectedBaby = mockBaby
            }
            return
        }

        isLoading = true
        defer {
            isLoading = false
            hasInitialLoad = true
        }
        do {
            var allBabies = try await RetryHelper.withRetry {
                try await self.firestoreService.fetchBabies(userId: userId)
            }

            // 공유된 아기도 로드 (병렬 패치, 1개 실패해도 나머지 계속)
            let sharedAccess: [SharedBabyAccess]
            do {
                sharedAccess = try await firestoreService.fetchSharedAccess(userId: userId)
            } catch {
                logSilent("공유 접근 로드 실패", error: error, logger: AppLogger.firestore)
                sharedAccess = []
            }
            let sharedBabies = await withTaskGroup(of: Baby?.self) { group in
                for access in sharedAccess {
                    group.addTask {
                        do {
                            guard var baby = try await self.firestoreService.fetchBaby(userId: access.ownerUserId, babyId: access.babyId) else { return nil }
                            // Tag shared baby with its owner's userId so all data loads use the correct Firestore path
                            baby.ownerUserId = access.ownerUserId
                            return baby
                        } catch {
                            logSilent("공유 아기 로드 실패: \(access.babyId)", error: error, logger: AppLogger.firestore)
                            return nil
                        }
                    }
                }
                var results: [Baby] = []
                for await baby in group {
                    if let baby { results.append(baby) }
                }
                return results
            }
            for baby in sharedBabies where !allBabies.contains(where: { $0.id == baby.id }) {
                allBabies.append(baby)
            }

            // Tag own babies with the current user's ID for consistency
            for index in allBabies.indices where allBabies[index].ownerUserId == nil {
                allBabies[index].ownerUserId = userId
            }

            babies = allBabies
            // 계정 전환 시 이전 계정 selectedBaby 잔존 방지 — 새 목록 기준 재검증
            selectedBaby = Self.resolveSelection(current: selectedBaby, in: babies)
        } catch {
            errorMessage = "아기 정보를 불러오지 못했습니다: \(error.localizedDescription)"
        }
    }

    func addBaby(userId: String) async {
        guard isFormValid else {
            errorMessage = "아기 이름을 입력해주세요."
            return
        }

        isLoading = true
        defer { isLoading = false }
        errorMessage = nil

        var baby = Baby(
            name: babyName.trimmingCharacters(in: .whitespaces),
            birthDate: babyBirthDate,
            gender: babyGender,
            bloodType: babyBloodType
        )

        do {
            if let photo = babyPhoto {
                let url = try await storageService.uploadBabyPhoto(photo, userId: userId, babyId: baby.id)
                baby.photoURL = url
            }
            try await firestoreService.createBaby(baby, userId: userId)
            babies.append(baby)
            if selectedBaby == nil {
                selectedBaby = baby
            }
            resetForm()
            showAddBaby = false
        } catch {
            errorMessage = "아기 추가에 실패했습니다: \(error.localizedDescription)"
        }
    }

    func updateBaby(_ baby: Baby, userId: String) async {
        guard let index = babies.firstIndex(where: { $0.id == baby.id }) else { return }

        let backup = babies[index]
        var updated = baby
        updated.updatedAt = Date()
        babies[index] = updated

        do {
            try await firestoreService.updateBaby(updated, userId: userId)
            if selectedBaby?.id == baby.id {
                selectedBaby = updated
            }
        } catch {
            babies[index] = backup // 롤백
            if selectedBaby?.id == baby.id {
                selectedBaby = backup
            }
            errorMessage = "아기 정보 수정에 실패했습니다: \(error.localizedDescription)"
        }
    }

    func deleteBaby(_ baby: Baby, userId: String) async {
        let backup = babies
        let backupSelected = selectedBaby
        babies.removeAll { $0.id == baby.id }
        if selectedBaby?.id == baby.id {
            selectedBaby = babies.first
        }

        do {
            try await firestoreService.deleteBaby(baby.id, userId: userId)
        } catch {
            babies = backup // 롤백
            selectedBaby = backupSelected
            errorMessage = "아기 삭제에 실패했습니다: \(error.localizedDescription)"
        }
    }

    func selectBaby(_ baby: Baby) {
        selectedBaby = baby
    }

    func resetForm() {
        babyName = ""
        babyBirthDate = Date()
        babyGender = .male
        babyBloodType = nil
        babyPhoto = nil
        errorMessage = nil
    }
}

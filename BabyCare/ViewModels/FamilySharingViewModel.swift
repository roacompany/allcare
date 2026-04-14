import Foundation

@MainActor @Observable
final class FamilySharingViewModel {
    var sharedAccess: [SharedBabyAccess] = []
    var generatedInvite: FamilyInvite?
    var isLoading = false
    var message: String?
    var errorMessage: String?

    private let firestoreService = FirestoreService.shared

    // MARK: - Fetch

    func fetchSharedAccess(userId: String) async {
        sharedAccess = (try? await firestoreService.fetchSharedAccess(userId: userId)) ?? []
    }

    // MARK: - Generate Invite

    func generateInvite(for baby: Baby, userId: String) async {
        isLoading = true
        defer { isLoading = false }

        let invite = FamilyInvite(
            ownerUserId: userId,
            babyId: baby.id,
            babyName: baby.name
        )
        do {
            try await firestoreService.saveInvite(invite)
            generatedInvite = invite
        } catch {
            message = "초대 코드 생성에 실패했습니다."
        }
    }

    // MARK: - Join Family

    func joinFamily(code: String, userId: String) async throws -> SharedBabyAccess {
        guard let invite = try await firestoreService.findInviteByCode(code) else {
            throw FamilySharingError.invalidCode
        }
        guard invite.expiresAt > Date() else {
            throw FamilySharingError.expiredCode
        }
        guard invite.ownerUserId != userId else {
            throw FamilySharingError.ownCode
        }

        let isDuplicate = try await firestoreService.checkDuplicateAccess(
            userId: userId,
            ownerUserId: invite.ownerUserId,
            babyId: invite.babyId
        )
        guard !isDuplicate else {
            throw FamilySharingError.alreadyJoined
        }

        let access = SharedBabyAccess(
            ownerUserId: invite.ownerUserId,
            babyId: invite.babyId,
            babyName: invite.babyName
        )
        try await firestoreService.saveSharedAccess(access, userId: userId)
        try? await firestoreService.markInviteUsed(invite.id)
        return access
    }

    // MARK: - Remove Shared Access

    func removeSharedAccess(access: SharedBabyAccess, userId: String) async {
        do {
            try await firestoreService.removeSharedAccess(accessId: access.id, userId: userId)
            sharedAccess.removeAll { $0.id == access.id }
        } catch {
            message = "공유 삭제에 실패했습니다. 다시 시도해 주세요."
        }
    }
}

// MARK: - Errors

enum FamilySharingError: LocalizedError {
    case invalidCode
    case expiredCode
    case ownCode
    case alreadyJoined

    var errorDescription: String? {
        switch self {
        case .invalidCode: return "유효하지 않은 코드입니다."
        case .expiredCode: return "만료된 초대 코드입니다."
        case .ownCode: return "본인의 초대 코드는 사용할 수 없습니다."
        case .alreadyJoined: return "이미 참여한 아기입니다."
        }
    }
}

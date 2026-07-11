import Foundation
import FirebaseStorage
import UIKit

/// BabyViewModel / DiaryViewModel / AuthViewModel 이 의존하는 사진 업로드·정리 narrow protocol (ISP).
/// Mock 으로 호출 검증 가능 — 실제 압축/업로드는 통합 테스트에서 검증.
protocol StorageServiceProviding: Sendable {
    func uploadBabyPhoto(_ image: UIImage, userId: String, babyId: String) async throws -> String
    func uploadDiaryPhoto(_ image: UIImage, userId: String, babyId: String, diaryId: String, index: Int) async throws -> String
    func deleteBabyStorage(userId: String, babyId: String) async throws
    func deleteUserStorage(userId: String) async throws
}

extension StorageService: StorageServiceProviding {}

/// Storage 사진 경로 단일 소스 — 업로드와 purge 가 같은 트리를 보도록 강제.
/// ⚠️ 형식 변경 금지: 기존 업로드 파일 도달성 계약 (BabyCareTests 가 잠금).
enum StoragePath {
    static func userRoot(userId: String) -> String {
        "users/\(userId)"
    }
    static func babyRoot(userId: String, babyId: String) -> String {
        "\(userRoot(userId: userId))/babies/\(babyId)"
    }
    static func babyProfile(userId: String, babyId: String) -> String {
        "\(babyRoot(userId: userId, babyId: babyId))/profile.jpg"
    }
    static func activityPhoto(userId: String, babyId: String, activityId: String) -> String {
        "\(babyRoot(userId: userId, babyId: babyId))/activities/\(activityId).jpg"
    }
    static func diaryPhoto(userId: String, babyId: String, diaryId: String, index: Int) -> String {
        "\(babyRoot(userId: userId, babyId: babyId))/diary/\(diaryId)_\(index).jpg"
    }
}

final class StorageService: Sendable {
    static let shared = StorageService()
    nonisolated(unsafe) private let storage = Storage.storage()

    private init() {}

    func uploadImage(_ image: UIImage, path: String) async throws -> String {
        guard let resized = image.resized(maxDimension: AppConstants.maxPhotoDimension),
              let data = resized.jpegData(compressionQuality: AppConstants.photoCompressionQuality) else {
            throw StorageError.compressionFailed
        }

        let ref = storage.reference().child(path)
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        _ = try await ref.putDataAsync(data, metadata: metadata)
        let url = try await ref.downloadURL()
        return url.absoluteString
    }

    func uploadBabyPhoto(_ image: UIImage, userId: String, babyId: String) async throws -> String {
        try await uploadImage(image, path: StoragePath.babyProfile(userId: userId, babyId: babyId))
    }

    func uploadActivityPhoto(_ image: UIImage, userId: String, babyId: String, activityId: String) async throws -> String {
        try await uploadImage(image, path: StoragePath.activityPhoto(userId: userId, babyId: babyId, activityId: activityId))
    }

    func uploadDiaryPhoto(_ image: UIImage, userId: String, babyId: String, diaryId: String, index: Int) async throws -> String {
        try await uploadImage(image, path: StoragePath.diaryPhoto(userId: userId, babyId: babyId, diaryId: diaryId, index: index))
    }

    func deleteImage(path: String) async throws {
        try await storage.reference().child(path).delete()
    }

    // MARK: - Purge (계정/아기 삭제 시 사진 정리 — PII 잔존 방지)

    func deleteBabyStorage(userId: String, babyId: String) async throws {
        try await deleteFolder(storage.reference().child(StoragePath.babyRoot(userId: userId, babyId: babyId)))
    }

    func deleteUserStorage(userId: String) async throws {
        try await deleteFolder(storage.reference().child(StoragePath.userRoot(userId: userId)))
    }

    /// Storage 는 서버측 prefix 삭제가 없어 listAll 후 항목별 삭제 (하위 폴더 재귀). 빈 폴더는 no-op.
    private func deleteFolder(_ reference: StorageReference) async throws {
        let listing = try await reference.listAll()
        for item in listing.items {
            try await item.delete()
        }
        for prefix in listing.prefixes {
            try await deleteFolder(prefix)
        }
    }

    enum StorageError: LocalizedError {
        case compressionFailed

        var errorDescription: String? {
            switch self {
            case .compressionFailed:
                return "이미지 압축에 실패했습니다."
            }
        }
    }
}

extension UIImage {
    func resized(maxDimension: CGFloat) -> UIImage? {
        let ratio = max(size.width, size.height) / maxDimension
        guard ratio > 1 else { return self }
        let newSize = CGSize(width: size.width / ratio, height: size.height / ratio)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

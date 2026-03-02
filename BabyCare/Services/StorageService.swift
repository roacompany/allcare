import Foundation
import FirebaseStorage
import UIKit

final class StorageService: Sendable {
    static let shared = StorageService()
    private let storage = Storage.storage()

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
        let path = "users/\(userId)/babies/\(babyId)/profile.jpg"
        return try await uploadImage(image, path: path)
    }

    func uploadActivityPhoto(_ image: UIImage, userId: String, babyId: String, activityId: String) async throws -> String {
        let path = "users/\(userId)/babies/\(babyId)/activities/\(activityId).jpg"
        return try await uploadImage(image, path: path)
    }

    func uploadDiaryPhoto(_ image: UIImage, userId: String, babyId: String, diaryId: String, index: Int) async throws -> String {
        let path = "users/\(userId)/babies/\(babyId)/diary/\(diaryId)_\(index).jpg"
        return try await uploadImage(image, path: path)
    }

    func deleteImage(path: String) async throws {
        try await storage.reference().child(path).delete()
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

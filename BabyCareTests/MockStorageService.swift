import Foundation
import UIKit
@testable import BabyCare

/// BabyViewModel / DiaryViewModel 사진 업로드 테스트용 Mock.
///
/// 압축/네트워크 없이 결정적 URL 반환. 호출 인자 + 횟수 검증.
/// Swift 6 Sendable: 단일 쓰레드 테스트 전용이므로 `@unchecked Sendable`.
final class MockStorageService: StorageServiceProviding, @unchecked Sendable {
    // MARK: - 스텁 응답

    /// uploadBabyPhoto / uploadDiaryPhoto 반환 URL prefix. 호출마다 `_${index}` suffix.
    var urlPrefix: String = "https://mock.storage/photo"

    // MARK: - 에러 주입

    var errorOnUploadBabyPhoto: Error?
    var errorOnUploadDiaryPhoto: Error?
    var errorOnDeleteBabyStorage: Error?
    var errorOnDeleteUserStorage: Error?

    // MARK: - 호출 카운터

    private(set) var babyUploads: [(userId: String, babyId: String)] = []
    private(set) var diaryUploads: [(userId: String, babyId: String, diaryId: String, index: Int)] = []
    private(set) var babyStorageDeletes: [(userId: String, babyId: String)] = []
    private(set) var userStorageDeletes: [String] = []

    var babyUploadCount: Int { babyUploads.count }
    var diaryUploadCount: Int { diaryUploads.count }

    // MARK: - Protocol Conformance

    func uploadBabyPhoto(_ image: UIImage, userId: String, babyId: String) async throws -> String {
        if let err = errorOnUploadBabyPhoto { throw err }
        babyUploads.append((userId: userId, babyId: babyId))
        return "\(urlPrefix)/baby/\(babyId)/\(babyUploads.count).jpg"
    }

    func uploadDiaryPhoto(_ image: UIImage, userId: String, babyId: String, diaryId: String, index: Int) async throws -> String {
        if let err = errorOnUploadDiaryPhoto { throw err }
        diaryUploads.append((userId: userId, babyId: babyId, diaryId: diaryId, index: index))
        return "\(urlPrefix)/diary/\(diaryId)_\(index).jpg"
    }

    func deleteBabyStorage(userId: String, babyId: String) async throws {
        if let err = errorOnDeleteBabyStorage { throw err }
        babyStorageDeletes.append((userId: userId, babyId: babyId))
    }

    func deleteUserStorage(userId: String) async throws {
        if let err = errorOnDeleteUserStorage { throw err }
        userStorageDeletes.append(userId)
    }
}

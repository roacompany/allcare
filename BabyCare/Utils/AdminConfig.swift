import Foundation

enum AdminConfig {
    static let adminUIDs: Set<String> = [
        "8EAUezvUyYTzhNVw9VO6GKKyhhx2"
    ]

    static func isAdmin(_ uid: String?) -> Bool {
        guard let uid else { return false }
        return adminUIDs.contains(uid)
    }
}

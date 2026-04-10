import Foundation
import FirebaseFirestore

struct Announcement: Identifiable, Codable, Hashable, @unchecked Sendable {
    // @unchecked Sendable: Firebase @DocumentID lacks Sendable conformance
    @DocumentID var id: String?
    var title: String
    var content: String
    var createdAt: Date
    var isActive: Bool
    var priority: Priority

    enum Priority: String, Codable, Comparable {
        case low, normal, high, urgent

        private var sortOrder: Int {
            switch self {
            case .low: return 0
            case .normal: return 1
            case .high: return 2
            case .urgent: return 3
            }
        }

        static func < (lhs: Priority, rhs: Priority) -> Bool {
            lhs.sortOrder < rhs.sortOrder
        }
    }
}

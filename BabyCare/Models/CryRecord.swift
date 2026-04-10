import Foundation

struct CryRecord: Identifiable, Codable, Hashable {
    let id: String
    let babyId: String
    let recordedAt: Date
    let durationSeconds: Double
    /// Stored as [String: Double] for Firestore/JSON Codable compatibility.
    /// Keys are CryLabel raw values.
    let probabilities: [String: Double]
    let topLabel: CryLabel?
    let isStub: Bool
    let note: String?

    /// Typed accessor for probabilities.
    var labelProbabilities: [CryLabel: Double] {
        var result: [CryLabel: Double] = [:]
        for (key, value) in probabilities {
            if let label = CryLabel(rawValue: key) {
                result[label] = value
            }
        }
        return result
    }

    init(
        id: String = UUID().uuidString,
        babyId: String,
        recordedAt: Date = Date(),
        durationSeconds: Double,
        probabilities: [String: Double],
        topLabel: CryLabel? = nil,
        isStub: Bool,
        note: String? = nil
    ) {
        self.id = id
        self.babyId = babyId
        self.recordedAt = recordedAt
        self.durationSeconds = durationSeconds
        self.probabilities = probabilities
        self.topLabel = topLabel
        self.isStub = isStub
        self.note = note
    }
}

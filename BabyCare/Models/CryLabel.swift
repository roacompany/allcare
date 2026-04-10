import Foundation

enum CryLabel: String, Codable, CaseIterable, Hashable {
    case hungry
    case burping
    case bellyPain
    case discomfort
    case tired

    var localizedDescription: String {
        switch self {
        case .hungry:     return "배고픔"
        case .burping:    return "트림"
        case .bellyPain:  return "복부 불편"
        case .discomfort: return "불편함"
        case .tired:      return "졸림"
        }
    }
}

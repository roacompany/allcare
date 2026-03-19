import Foundation

extension Activity {
        // MARK: - 대변 색상

    enum StoolColor: String, Codable, CaseIterable {
        case yellow, green, brown, dark, red, white

        var displayName: String {
            switch self {
            case .yellow: "노란색"
            case .green: "녹색"
            case .brown: "갈색"
            case .dark: "짙은색"
            case .red: "붉은색"
            case .white: "흰색"
            }
        }

        var colorHex: String {
            switch self {
            case .yellow: "DAA520"
            case .green: "4CAF50"
            case .brown: "8B4513"
            case .dark: "3E2723"
            case .red: "D32F2F"
            case .white: "E0E0E0"
            }
        }

        var needsAttention: Bool {
            self == .red || self == .white
        }
    }

    // MARK: - 대변 농도

    enum StoolConsistency: String, Codable, CaseIterable {
        case watery, soft, normal, hard

        var displayName: String {
            switch self {
            case .watery: "묽음"
            case .soft: "무름"
            case .normal: "보통"
            case .hard: "딱딱함"
            }
        }

        var icon: String {
            switch self {
            case .watery: "drop.fill"
            case .soft: "cloud.fill"
            case .normal: "circle.fill"
            case .hard: "diamond.fill"
            }
        }
    }

    // MARK: - 수면 질

    enum SleepQualityType: String, Codable, CaseIterable {
        case good, fussy, light

        var displayName: String {
            switch self {
            case .good: "잘 잠"
            case .fussy: "뒤척임"
            case .light: "얕은 수면"
            }
        }

        var icon: String {
            switch self {
            case .good: "moon.fill"
            case .fussy: "figure.walk"
            case .light: "cloud.moon.fill"
            }
        }
    }

    // MARK: - 잠드는 방법

    enum SleepMethodType: String, Codable, CaseIterable {
        case selfSettled, nursing, holding, stroller, carSeat

        var displayName: String {
            switch self {
            case .selfSettled: "스스로"
            case .nursing: "수유 중"
            case .holding: "안아서"
            case .stroller: "유모차"
            case .carSeat: "카시트"
            }
        }

        var icon: String {
            switch self {
            case .selfSettled: "bed.double.fill"
            case .nursing: "figure.and.child.holdinghands"
            case .holding: "hands.and.sparkles.fill"
            case .stroller: "stroller.fill"
            case .carSeat: "car.fill"
            }
        }
    }

    var durationText: String? {
        guard let duration else { return nil }
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        if hours > 0 {
            return "\(hours)시간 \(minutes)분"
        }
        return "\(minutes)분"
    }

    var amountText: String? {
        guard let amount else { return nil }
        return "\(Int(amount))ml"
    }
}

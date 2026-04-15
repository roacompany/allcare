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
        // 기존 레코드 decode 호환을 위해 전체 case 유지.
        // UI 픽커에서는 `selectableCases`만 노출 — holding/nursing은 deprecated.
        case bed, selfSettled, holding, inArms, bouncer, nursing, stroller, carSeat

        /// 신규 기록 입력 시 사용자에게 노출되는 case만. 중복/카테고리 불일치 제외.
        /// - holding: inArms와 의미 중복 (안아서 == 품에 안겨서) → inArms로 통합
        /// - nursing: 상황(행위)이지 장소가 아님 → 수유 Activity로 별도 기록
        static let selectableCases: [SleepMethodType] = [
            .bed, .selfSettled, .inArms, .bouncer, .stroller, .carSeat
        ]

        var displayName: String {
            switch self {
            case .bed: "침대"
            case .selfSettled: "스스로"
            case .holding: "품에 안겨서"
            case .inArms: "품에 안겨서"
            case .bouncer: "바운서"
            case .nursing: "수유 중"
            case .stroller: "유모차"
            case .carSeat: "카시트"
            }
        }

        var icon: String {
            switch self {
            case .bed: "bed.double.fill"
            case .selfSettled: "moon.zzz.fill"
            case .holding: "figure.arms.open"
            case .inArms: "figure.arms.open"
            case .bouncer: "chair.lounge.fill"
            case .nursing: "figure.and.child.holdinghands"
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

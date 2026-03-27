import SwiftUI

// MARK: - Color(hex:) — 위젯 자체 정의 (Extensions.swift는 DateFormatters 의존으로 직접 공유 불가)

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let scanner = Scanner(string: hex)
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)

        let r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = Double(rgbValue & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Time Helpers

enum WidgetTimeHelper {
    static func timeAgo(_ date: Date, from now: Date = Date()) -> String {
        let minutes = Int(now.timeIntervalSince(date) / 60)
        if minutes < 1 { return "방금" }
        if minutes < 60 { return "\(minutes)분 전" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)시간 전" }
        return "\(hours / 24)일 전"
    }

    static func timeUntil(_ date: Date, from now: Date = Date()) -> String {
        let minutes = Int(date.timeIntervalSince(now) / 60)
        if minutes < 1 { return "곧" }
        if minutes < 60 { return "\(minutes)분 후" }
        let hours = minutes / 60
        return "\(hours)시간 \(minutes % 60)분 후"
    }

    static func shortTimeAgo(_ date: Date, from now: Date = Date()) -> String {
        let minutes = Int(now.timeIntervalSince(date) / 60)
        if minutes < 1 { return "방금" }
        if minutes < 60 { return "\(minutes)분" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h" }
        return "\(hours / 24)d"
    }
}

// MARK: - Widget Gradient

enum WidgetGradient {
    static let pastel = LinearGradient(
        colors: [Color(hex: "FFE5EC"), Color(hex: "FFF0E5")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let pastelDark = LinearGradient(
        colors: [Color(hex: "3D2B32"), Color(hex: "3D3228")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static func background(_ scheme: ColorScheme) -> LinearGradient {
        scheme == .dark ? pastelDark : pastel
    }
}

// MARK: - Widget Colors

enum WidgetColors {
    static func feeding(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "FFB2C6") : Color(hex: "FF9FB5")
    }
    static func feedingText(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "FF8DAA") : Color(hex: "FF6B8A")
    }
    static func sleep(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "8FB2F2") : Color(hex: "7B9FE8")
    }
    static func diaper(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "99D1B4") : Color(hex: "85C1A3")
    }
    static func cardBackground(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: "2C2C32") : Color.white
    }
    static func divider(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.15) : Color(hex: "FFD4DE")
    }
}

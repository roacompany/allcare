import Foundation

/// 구글지도 주소 방식(Maps URLs) — API 키가 필요 없고 무료다. 앱이 깔려 있으면 앱으로, 없으면 웹으로 열린다.
/// https://developers.google.com/maps/documentation/urls/get-started
enum GoogleMapsLink {
    static func place(_ query: String) -> URL? {
        guard let q = encode(query) else { return nil }
        return URL(string: "https://www.google.com/maps/search/?api=1&query=\(q)")
    }

    static func directions(from origin: String, to destination: String) -> URL? {
        guard let o = encode(origin), let d = encode(destination) else { return nil }
        return URL(string: "https://www.google.com/maps/dir/?api=1&origin=\(o)&destination=\(d)&travelmode=driving")
    }

    /// 값 안의 & = + ? # 까지 인코딩한다(주소에 들어 있으면 쿼리가 끊긴다).
    private static func encode(_ s: String) -> String? {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let allowed = CharacterSet.urlQueryAllowed.subtracting(CharacterSet(charactersIn: "&=+?#"))
        return trimmed.addingPercentEncoding(withAllowedCharacters: allowed)
    }
}

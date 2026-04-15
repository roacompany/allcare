import SwiftUI
import SafariServices

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        let vc = SFSafariViewController(url: url, configuration: config)
        vc.preferredControlTintColor = .systemBlue
        return vc
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

enum CoupangAffiliateService {
    static func buildSearchKeyword(for product: BabyProduct) -> String {
        var parts: [String] = []

        if let brand = product.brand, !brand.isEmpty {
            parts.append(brand)
        }

        parts.append(product.name)

        if let size = product.size, !size.isEmpty {
            parts.append(size)
        }

        return parts.joined(separator: " ")
    }

    static func searchURL(for product: BabyProduct) -> URL? {
        let keyword = buildSearchKeyword(for: product)
        return CoupangConfig.searchURL(keyword: keyword)
    }

    static func reorderURL(for product: BabyProduct) -> URL? {
        if let coupangURL = product.coupangURL, !coupangURL.isEmpty {
            return URL(string: coupangURL)
        }
        return searchURL(for: product)
    }

    // MARK: - Recommendation Deep Link

    /// 추천 용품명 기반 쿠팡 딥링크를 반환합니다.
    /// coupangKeyword가 있으면 해당 키워드로, 없으면 productName으로 검색 URL을 생성합니다.
    static func deepLink(productName: String, keyword: String? = nil) -> URL? {
        let searchKeyword = keyword ?? productName
        return CoupangConfig.searchURL(keyword: searchKeyword)
    }

    /// ProductRecommendation 기반 쿠팡 검색 URL 반환.
    static func searchURL(for recommendation: ProductRecommendation) -> URL? {
        let keyword = recommendation.coupangKeyword ?? recommendation.name
        return CoupangConfig.searchURL(keyword: keyword)
    }
}

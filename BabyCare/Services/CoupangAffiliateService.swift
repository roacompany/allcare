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
}

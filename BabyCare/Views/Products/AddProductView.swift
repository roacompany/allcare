import SwiftUI

struct AddProductView: View {
    @Environment(ProductViewModel.self) var productVM
    @Environment(BabyViewModel.self) var babyVM
    @Environment(AuthViewModel.self) var authVM
    @Environment(\.dismiss) var dismiss

    enum AddMode { case catalog, manual }

    @State var mode: AddMode = .catalog
    @State var catalogSearch = ""
    @State var catalogCategory: BabyProduct.ProductCategory? = nil
    @State var inlineSuggestions: [CatalogProduct] = []

    // MARK: - Filtered catalog list

    var filteredCatalog: [CatalogProduct] {
        var items = productVM.catalog
        if let cat = catalogCategory {
            items = items.filter { $0.category == cat.rawValue }
        }
        if !catalogSearch.isEmpty {
            let q = catalogSearch.lowercased()
            items = items.filter {
                $0.name.lowercased().contains(q) ||
                $0.brand.lowercased().contains(q) ||
                $0.tags.contains(where: { $0.lowercased().contains(q) })
            }
        }
        return items
    }

    // MARK: - Body

    var body: some View {
        @Bindable var vm = productVM

        NavigationStack {
            Group {
                if mode == .catalog {
                    catalogModeView
                } else {
                    manualModeView
                }
            }
            .navigationTitle("용품 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        productVM.resetForm()
                        dismiss()
                    }
                }
                if mode == .manual {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("추가") {
                            Task {
                                guard let userId = authVM.currentUserId else { return }
                                await productVM.addProduct(userId: userId)
                                dismiss()
                            }
                        }
                        .disabled(productVM.name.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    func categoryIcon(for categoryRaw: String) -> String {
        BabyProduct.ProductCategory(rawValue: categoryRaw)?.icon ?? "bag.fill"
    }

    func selectCatalogProduct(_ item: CatalogProduct) {
        applyCatalogProduct(item)
        mode = .manual
    }

    func applyCatalogProduct(_ item: CatalogProduct) {
        productVM.selectedCatalogProduct = item
        productVM.name = item.name
        productVM.brand = item.brand
        if let cat = BabyProduct.ProductCategory(rawValue: item.category) {
            productVM.category = cat
        }
        inlineSuggestions = []
    }

    func updateInlineSuggestions(for text: String) {
        guard productVM.selectedCatalogProduct == nil else {
            inlineSuggestions = []
            return
        }
        guard text.count >= 2 else {
            inlineSuggestions = []
            return
        }
        inlineSuggestions = CatalogService.findMatches(
            userText: text,
            category: productVM.category,
            catalog: productVM.catalog
        )
    }
}

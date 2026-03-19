import SwiftUI

struct ProductDetailView: View {
    let product: BabyProduct
    @Environment(ProductViewModel.self) var productVM
    @Environment(PurchaseViewModel.self) var purchaseVM
    @Environment(AuthViewModel.self) var authVM
    @Environment(\.dismiss) var dismiss

    @State var showDeleteAlert = false
    @State var useAmount = 1
    @State var showSafari = false
    @State var safariURL: URL?
    @State var showAddPurchase = false

    var body: some View {
        List {
                infoSections
                purchaseSections1
                purchaseSections2
        }
        .navigationTitle(product.category.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .alert("용품 삭제", isPresented: $showDeleteAlert) {
            Button("취소", role: .cancel) {}
            Button("삭제", role: .destructive) {
                Task {
                    guard let userId = authVM.currentUserId else { return }
                    await productVM.deleteProduct(product, userId: userId)
                    dismiss()
                }
            }
        } message: {
            Text("'\(product.name)'을(를) 삭제하시겠습니까?")
        }
        .sheet(isPresented: $showSafari) {
            if let url = safariURL {
                SafariView(url: url)
                    .ignoresSafeArea()
            }
        }
        .sheet(isPresented: $showAddPurchase) {
            AddPurchaseRecordView(product: product)
        }
        .task {
            guard let userId = authVM.currentUserId else { return }
            if purchaseVM.records.isEmpty {
                await purchaseVM.loadRecords(userId: userId)
            }
        }
    }
}

import SwiftUI

struct AddPurchaseRecordView: View {
    let product: BabyProduct
    @Environment(PurchaseViewModel.self) private var purchaseVM
    @Environment(AuthViewModel.self) private var authVM
    @Environment(\.dismiss) private var dismiss

    @State private var price: String
    @State private var quantity = 1
    @State private var store: String
    @State private var purchaseDate = Date()
    @State private var note = ""

    init(product: BabyProduct) {
        self.product = product
        _price = State(initialValue: product.purchasePrice.map { String($0) } ?? "")
        _store = State(initialValue: product.purchaseStore ?? "쿠팡")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("상품 정보") {
                    HStack {
                        Text("상품명")
                        Spacer()
                        Text(product.name)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("카테고리")
                        Spacer()
                        Text(product.category.displayName)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("구매 정보") {
                    HStack {
                        Text("가격")
                        Spacer()
                        TextField("0", text: $price)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                        Text("원")
                            .foregroundStyle(.secondary)
                    }

                    Stepper("수량: \(quantity)개", value: $quantity, in: 1...999)

                    HStack {
                        Text("구매처")
                        Spacer()
                        TextField("쿠팡", text: $store)
                            .multilineTextAlignment(.trailing)
                    }

                    DatePicker("구매일", selection: $purchaseDate, in: ...Date(), displayedComponents: .date)
                }

                Section("메모") {
                    TextField("메모 (선택)", text: $note)
                }
            }
            .navigationTitle("구매 기록 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        save()
                    }
                    .bold()
                    .disabled(Int(price) == nil || Int(price)! <= 0)
                }
            }
        }
    }

    private func save() {
        guard let priceValue = Int(price), priceValue > 0,
              let userId = authVM.currentUserId else { return }

        Task {
            await purchaseVM.recordPurchase(
                product: product,
                price: priceValue,
                quantity: quantity,
                store: store.isEmpty ? "쿠팡" : store,
                purchaseDate: purchaseDate,
                isAffiliate: false,
                note: note.isEmpty ? nil : note,
                userId: userId
            )
            dismiss()
        }
    }
}

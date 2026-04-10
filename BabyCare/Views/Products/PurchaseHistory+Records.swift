import SwiftUI
import Charts

extension PurchaseHistoryView {
    // MARK: - Records List

    var recordsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("전체 구매 기록")
                .font(.headline)

            ForEach(purchaseVM.filteredRecords) { record in
                HStack(spacing: 12) {
                    Image(systemName: record.category.icon)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .frame(width: 30)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(record.productName)
                            .font(.subheadline.weight(.medium))
                            .lineLimit(1)
                        HStack(spacing: 6) {
                            Text(record.store)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                            Text(DateFormatters.shortDate.string(from: record.purchaseDate))
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(formattedPrice(record.price * record.quantity))
                            .font(.subheadline.monospacedDigit())
                        if record.quantity > 1 {
                            Text("\(record.quantity)개")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
                .onTapGesture {
                    purchaseVM.editingRecord = record
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        Task {
                            guard let userId = authVM.currentUserId else { return }
                            await purchaseVM.deleteRecord(record, userId: userId)
                        }
                    } label: {
                        Label("삭제", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                    Button {
                        purchaseVM.editingRecord = record
                    } label: {
                        Label("수정", systemImage: "pencil")
                    }
                    .tint(.blue)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
        )
        .sheet(item: Binding(
            get: { purchaseVM.editingRecord },
            set: { purchaseVM.editingRecord = $0 }
        )) { record in
            EditPurchaseRecordView(record: record)
        }
    }

    // MARK: - Helpers

    func formattedPrice(_ price: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return (formatter.string(from: NSNumber(value: price)) ?? "\(price)") + "원"
    }

    func shortPrice(_ value: Int) -> String {
        if value >= 10000 {
            return "\(value / 10000)만"
        } else if value >= 1000 {
            return "\(value / 1000)천"
        }
        return "\(value)"
    }
}

// MARK: - Edit Purchase Record View

struct EditPurchaseRecordView: View {
    let record: PurchaseRecord
    @Environment(PurchaseViewModel.self) private var purchaseVM
    @Environment(AuthViewModel.self) private var authVM
    @Environment(\.dismiss) private var dismiss

    @State private var price: String
    @State private var quantity: Int
    @State private var store: String
    @State private var purchaseDate: Date
    @State private var note: String

    init(record: PurchaseRecord) {
        self.record = record
        _price = State(initialValue: String(record.price))
        _quantity = State(initialValue: record.quantity)
        _store = State(initialValue: record.store)
        _purchaseDate = State(initialValue: record.purchaseDate)
        _note = State(initialValue: record.note ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("상품 정보") {
                    HStack {
                        Text("상품명")
                        Spacer()
                        Text(record.productName)
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("카테고리")
                        Spacer()
                        Text(record.category.displayName)
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
            .navigationTitle("구매 기록 수정")
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

        var updated = record
        updated.price = priceValue
        updated.quantity = quantity
        updated.store = store.isEmpty ? "쿠팡" : store
        updated.purchaseDate = purchaseDate
        updated.note = note.isEmpty ? nil : note

        Task {
            await purchaseVM.updateRecord(updated, userId: userId)
            dismiss()
        }
    }
}

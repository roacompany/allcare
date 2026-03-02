import SwiftUI

struct ProductDetailView: View {
    let product: BabyProduct
    @Environment(ProductViewModel.self) private var productVM
    @Environment(AuthViewModel.self) private var authVM
    @Environment(\.dismiss) private var dismiss

    @State private var showDeleteAlert = false
    @State private var useAmount = 1

    var body: some View {
        List {
            // Header
            Section {
                VStack(spacing: 12) {
                    Image(systemName: product.category.icon)
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                        .frame(width: 80, height: 80)
                        .background(Color(.systemGray6))
                        .clipShape(Circle())

                    Text(product.name)
                        .font(.title3.weight(.semibold))

                    if let brand = product.brand {
                        Text(brand)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if !product.isActive {
                        Text("사용 완료")
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color(.systemGray5))
                            .clipShape(Capsule())
                    }
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }

            // Quick Use
            if product.isActive, product.remainingQuantity != nil {
                Section("사용 기록") {
                    Stepper("사용량: \(useAmount)개", value: $useAmount, in: 1...99)

                    Button {
                        Task {
                            guard let userId = authVM.currentUserId else { return }
                            await productVM.useProduct(product, amount: useAmount, userId: userId)
                            useAmount = 1
                        }
                    } label: {
                        Label("사용 기록하기", systemImage: "minus.circle.fill")
                    }
                }
            }

            // Stock info
            if product.quantity != nil || product.remainingQuantity != nil {
                Section("재고") {
                    if let total = product.quantity {
                        HStack {
                            Text("구매 수량")
                            Spacer()
                            Text("\(total)개")
                                .foregroundStyle(.secondary)
                        }
                    }
                    if let remaining = product.remainingQuantity {
                        HStack {
                            Text("남은 수량")
                            Spacer()
                            Text("\(remaining)개")
                                .foregroundStyle(product.isLowStock ? .orange : .secondary)
                        }
                    }
                    if product.reorderReminder, let threshold = product.reorderThreshold {
                        HStack {
                            Text("재구매 알림")
                            Spacer()
                            Text("\(threshold)개 이하")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            // Purchase info
            Section("구매 정보") {
                if let date = product.purchaseDate {
                    HStack {
                        Text("구매일")
                        Spacer()
                        Text(DateFormatters.fullDate.string(from: date))
                            .foregroundStyle(.secondary)
                    }
                }
                if let price = product.priceText {
                    HStack {
                        Text("가격")
                        Spacer()
                        Text(price)
                            .foregroundStyle(.secondary)
                    }
                }
                if let store = product.purchaseStore {
                    HStack {
                        Text("구매처")
                        Spacer()
                        Text(store)
                            .foregroundStyle(.secondary)
                    }
                }
                if let size = product.size {
                    HStack {
                        Text("사이즈")
                        Spacer()
                        Text(size)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Baby reaction
            if product.babyReaction != nil || product.allergyNote != nil || product.rating != nil {
                Section("아기 반응") {
                    if let reaction = product.babyReaction {
                        HStack {
                            Text("반응")
                            Spacer()
                            Text("\(reaction.emoji) \(reaction.displayName)")
                        }
                    }
                    if let rating = product.rating {
                        HStack {
                            Text("평점")
                            Spacer()
                            HStack(spacing: 2) {
                                ForEach(1...5, id: \.self) { star in
                                    Image(systemName: star <= rating ? "star.fill" : "star")
                                        .font(.caption)
                                        .foregroundStyle(star <= rating ? .yellow : .secondary)
                                }
                            }
                        }
                    }
                    if let allergyNote = product.allergyNote {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("알러지/주의사항")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(allergyNote)
                                .foregroundStyle(.red)
                        }
                    }
                }
            }

            // Dates
            if product.openedDate != nil || product.expiryDate != nil {
                Section("날짜") {
                    if let opened = product.openedDate {
                        HStack {
                            Text("개봉일")
                            Spacer()
                            Text(DateFormatters.shortDate.string(from: opened))
                                .foregroundStyle(.secondary)
                        }
                    }
                    if let expiry = product.expiryDate {
                        HStack {
                            Text("유통기한")
                            Spacer()
                            Text(DateFormatters.shortDate.string(from: expiry))
                                .foregroundStyle(product.isExpired ? .red : product.isExpiringSoon ? .orange : .secondary)
                        }
                    }
                }
            }

            // Note
            if let note = product.note {
                Section("메모") {
                    Text(note)
                }
            }

            // Actions
            Section {
                Button {
                    Task {
                        guard let userId = authVM.currentUserId else { return }
                        await productVM.toggleActive(product, userId: userId)
                    }
                } label: {
                    Label(
                        product.isActive ? "사용 완료로 변경" : "사용 중으로 변경",
                        systemImage: product.isActive ? "checkmark.circle" : "arrow.uturn.backward"
                    )
                }

                Button(role: .destructive) {
                    showDeleteAlert = true
                } label: {
                    Label("삭제", systemImage: "trash")
                }
            }
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
    }
}

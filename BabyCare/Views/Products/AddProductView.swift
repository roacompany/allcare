import SwiftUI

struct AddProductView: View {
    @Environment(ProductViewModel.self) private var productVM
    @Environment(BabyViewModel.self) private var babyVM
    @Environment(AuthViewModel.self) private var authVM
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var vm = productVM

        NavigationStack {
            Form {
                // Basic info
                Section("기본 정보") {
                    TextField("용품 이름 *", text: $vm.name)
                    TextField("브랜드", text: $vm.brand)

                    Picker("카테고리", selection: $vm.category) {
                        ForEach(BabyProduct.ProductCategory.allCases, id: \.self) { cat in
                            Label(cat.displayName, systemImage: cat.icon).tag(cat)
                        }
                    }

                    TextField("사이즈/단계", text: $vm.size)
                        .textContentType(.none)
                }

                // Purchase info
                Section("구매 정보") {
                    Toggle("구매일 기록", isOn: $vm.hasPurchaseDate)
                    if productVM.hasPurchaseDate {
                        DatePicker("구매일", selection: $vm.purchaseDate, displayedComponents: .date)
                            .environment(\.locale, Locale(identifier: "ko_KR"))
                    }

                    HStack {
                        Text("가격")
                        Spacer()
                        TextField("원", text: $vm.purchasePrice)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 120)
                    }

                    TextField("구매처", text: $vm.purchaseStore)
                }

                // Quantity
                Section("수량") {
                    HStack {
                        Text("수량")
                        Spacer()
                        TextField("개", text: $vm.quantity)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }

                    Toggle("재구매 알림", isOn: $vm.reorderReminder)

                    if productVM.reorderReminder {
                        HStack {
                            Text("알림 기준")
                            Spacer()
                            TextField("개 이하", text: $vm.reorderThreshold)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                        }
                    }
                }

                // Expiry
                Section("유통기한") {
                    Toggle("유통기한 있음", isOn: $vm.hasExpiry)
                    if productVM.hasExpiry {
                        DatePicker("유통기한", selection: Binding(
                            get: { productVM.expiryDate ?? Date() },
                            set: { productVM.expiryDate = $0 }
                        ), displayedComponents: .date)
                        .environment(\.locale, Locale(identifier: "ko_KR"))
                    }
                }

                // Baby reaction
                Section("아기 반응") {
                    HStack(spacing: 8) {
                        ForEach(BabyProduct.BabyReaction.allCases, id: \.self) { reaction in
                            Button {
                                productVM.babyReaction = productVM.babyReaction == reaction ? nil : reaction
                            } label: {
                                VStack(spacing: 2) {
                                    Text(reaction.emoji)
                                        .font(.title2)
                                    Text(reaction.displayName)
                                        .font(.caption2)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(
                                    productVM.babyReaction == reaction
                                        ? Color.accentColor.opacity(0.12)
                                        : Color.clear
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Star rating
                    HStack {
                        Text("평점")
                        Spacer()
                        HStack(spacing: 4) {
                            ForEach(1...5, id: \.self) { star in
                                Button {
                                    productVM.rating = productVM.rating == star ? nil : star
                                } label: {
                                    Image(systemName: star <= (productVM.rating ?? 0) ? "star.fill" : "star")
                                        .foregroundStyle(star <= (productVM.rating ?? 0) ? .yellow : .secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    TextField("알러지/주의사항", text: $vm.allergyNote)
                }

                // Note
                Section("메모") {
                    TextField("메모", text: $vm.note, axis: .vertical)
                        .lineLimit(3...6)
                }

                // Baby assignment
                if babyVM.babies.count > 1 {
                    Section("아기 선택") {
                        Picker("아기", selection: $vm.selectedBabyId) {
                            Text("전체").tag(String?.none)
                            ForEach(babyVM.babies) { baby in
                                Text(baby.name).tag(String?.some(baby.id))
                            }
                        }
                    }
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

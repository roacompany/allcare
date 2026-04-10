import SwiftUI

extension AddProductView {

    // MARK: - Manual mode

    var manualModeView: some View {
        Form {
            // Catalog suggestion banner
            if !inlineSuggestions.isEmpty && productVM.selectedCatalogProduct == nil {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("이 상품인가요?")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(inlineSuggestions) { item in
                                    Button {
                                        applyCatalogProduct(item)
                                    } label: {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(item.name)
                                                .font(.subheadline.weight(.medium))
                                                .lineLimit(1)
                                            Text(item.brand)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Color.accentColor.opacity(0.1))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            // Catalog linked indicator
            if let linked = productVM.selectedCatalogProduct {
                Section {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("카탈로그 연결됨")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(linked.brand) \(linked.name)")
                                .font(.subheadline.weight(.medium))
                        }
                        Spacer()
                        Button {
                            productVM.selectedCatalogProduct = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 2)
                }
            }

            // Basic info
            @Bindable var vm = productVM
            Section("기본 정보") {
                TextField("용품 이름 *", text: $vm.name)
                    .onChange(of: productVM.name) { _, newValue in
                        updateInlineSuggestions(for: newValue)
                    }
                TextField("브랜드", text: $vm.brand)

                Picker("카테고리", selection: $vm.category) {
                    ForEach(BabyProduct.ProductCategory.allCases, id: \.self) { cat in
                        Label(cat.displayName, systemImage: cat.icon).tag(cat)
                    }
                }
                .onChange(of: productVM.category) { _, newCat in
                    productVM.quantityUnit = newCat.defaultUnit
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
                Picker("단위", selection: $vm.quantityUnit) {
                    ForEach(BabyProduct.QuantityUnit.allCases, id: \.self) { unit in
                        Text(unit.displayName).tag(unit)
                    }
                }

                HStack {
                    Text("수량")
                    Spacer()
                    TextField(productVM.quantityUnit.displayName, text: $vm.quantity)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 120)
                    Text(productVM.quantityUnit.displayName)
                        .foregroundStyle(.secondary)
                }

                Toggle("재구매 알림", isOn: $vm.reorderReminder)

                if productVM.reorderReminder {
                    HStack {
                        Text("알림 기준")
                        Spacer()
                        TextField("\(productVM.quantityUnit.displayName) 이하", text: $vm.reorderThreshold)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 120)
                        Text(productVM.quantityUnit.displayName)
                            .foregroundStyle(.secondary)
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
    }
}

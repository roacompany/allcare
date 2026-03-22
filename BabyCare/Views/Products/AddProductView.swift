import SwiftUI

struct AddProductView: View {
    @Environment(ProductViewModel.self) private var productVM
    @Environment(BabyViewModel.self) private var babyVM
    @Environment(AuthViewModel.self) private var authVM
    @Environment(\.dismiss) private var dismiss

    enum AddMode { case catalog, manual }

    @State private var mode: AddMode = .catalog
    @State private var catalogSearch = ""
    @State private var catalogCategory: BabyProduct.ProductCategory? = nil
    @State private var inlineSuggestions: [CatalogProduct] = []

    // MARK: - Filtered catalog list

    private var filteredCatalog: [CatalogProduct] {
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

    // MARK: - Catalog mode

    private var catalogModeView: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("상품 검색...", text: $catalogSearch)
                    .autocorrectionDisabled()
                if !catalogSearch.isEmpty {
                    Button {
                        catalogSearch = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 8)

            // Category filter tabs
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    categoryChip(nil, label: "전체")
                    ForEach(BabyProduct.ProductCategory.allCases, id: \.self) { cat in
                        categoryChip(cat, label: cat.displayName)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 6)
            }

            Divider()

            // Catalog list or empty state
            if productVM.catalog.isEmpty {
                catalogLoadingOrEmpty
            } else if filteredCatalog.isEmpty {
                catalogNoResults
            } else {
                List {
                    ForEach(filteredCatalog) { item in
                        Button {
                            selectCatalogProduct(item)
                        } label: {
                            catalogRow(item)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .listStyle(.plain)
            }

            // Direct input CTA
            Spacer(minLength: 0)
            Divider()
            Button {
                productVM.resetForm()
                mode = .manual
            } label: {
                HStack {
                    Text("찾는 상품이 없나요?")
                        .foregroundStyle(.secondary)
                    Text("직접 입력하기")
                        .fontWeight(.medium)
                        .foregroundStyle(Color.accentColor)
                }
                .font(.subheadline)
                .padding(.vertical, 14)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Manual mode

    private var manualModeView: some View {
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
    }

    // MARK: - Sub-views

    @ViewBuilder
    private func categoryChip(_ cat: BabyProduct.ProductCategory?, label: String) -> some View {
        let isSelected = catalogCategory == cat
        Button {
            catalogCategory = isSelected ? nil : cat
        } label: {
            Text(label)
                .font(.subheadline)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isSelected ? Color.accentColor : Color(.systemGray6))
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func catalogRow(_ item: CatalogProduct) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 40, height: 40)
                Image(systemName: categoryIcon(for: item.category))
                    .foregroundStyle(Color.accentColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Text(item.brand)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var catalogLoadingOrEmpty: some View {
        VStack(spacing: 12) {
            if productVM.catalog.isEmpty {
                ProgressView()
                Text("카탈로그를 불러오는 중...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 60)
    }

    @ViewBuilder
    private var catalogNoResults: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("검색 결과가 없습니다")
                .font(.subheadline.weight(.medium))
            Text("\"\(catalogSearch)\"에 해당하는 카탈로그 상품이 없습니다.\n아래 직접 입력하기로 추가하세요.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 60)
        .padding(.horizontal)
    }

    // MARK: - Helpers

    private func categoryIcon(for categoryRaw: String) -> String {
        BabyProduct.ProductCategory(rawValue: categoryRaw)?.icon ?? "bag.fill"
    }

    private func selectCatalogProduct(_ item: CatalogProduct) {
        applyCatalogProduct(item)
        mode = .manual
    }

    private func applyCatalogProduct(_ item: CatalogProduct) {
        productVM.selectedCatalogProduct = item
        productVM.name = item.name
        productVM.brand = item.brand
        if let cat = BabyProduct.ProductCategory(rawValue: item.category) {
            productVM.category = cat
        }
        inlineSuggestions = []
    }

    private func updateInlineSuggestions(for text: String) {
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

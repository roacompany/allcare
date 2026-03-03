import SwiftUI

struct ProductListView: View {
    @Environment(ProductViewModel.self) private var productVM
    @Environment(AuthViewModel.self) private var authVM

    var body: some View {
        @Bindable var vm = productVM

        NavigationStack {
            VStack(spacing: 0) {
                // Search
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("용품 검색", text: $vm.searchText)
                }
                .padding(10)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal)
                .padding(.top, 8)

                // Category filter
                categoryFilter

                // Alerts banner
                if !productVM.lowStockProducts.isEmpty || !productVM.expiringSoonProducts.isEmpty {
                    alertsBanner
                }

                // Product list
                if productVM.filteredProducts.isEmpty && !productVM.isLoading {
                    EmptyStateView(
                        icon: "bag.fill",
                        title: "등록된 용품 없음",
                        message: "아기 용품을 등록하고 관리해보세요",
                        actionTitle: "용품 추가"
                    ) {
                        productVM.showAddProduct = true
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    productList
                }
            }
            .navigationTitle("용품 관리")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        productVM.showAddProduct = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .secondaryAction) {
                    NavigationLink {
                        ProductStatsView()
                    } label: {
                        Label("지출 통계", systemImage: "chart.pie.fill")
                    }
                }
                ToolbarItem(placement: .secondaryAction) {
                    NavigationLink {
                        PurchaseHistoryView()
                    } label: {
                        Label("구매 분석", systemImage: "chart.bar.xaxis")
                    }
                }
            }
            .sheet(isPresented: $vm.showAddProduct) {
                AddProductView()
            }
            .task {
                guard let userId = authVM.currentUserId else { return }
                await productVM.loadProducts(userId: userId)
            }
        }
    }

    // MARK: - Category Filter

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(
                    title: "전체",
                    isSelected: productVM.selectedCategory == nil
                ) {
                    productVM.selectedCategory = nil
                }

                ForEach(BabyProduct.ProductCategory.allCases, id: \.self) { cat in
                    FilterChip(
                        title: cat.displayName,
                        icon: cat.icon,
                        isSelected: productVM.selectedCategory == cat
                    ) {
                        productVM.selectedCategory = cat
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Alerts Banner

    private var alertsBanner: some View {
        VStack(spacing: 6) {
            ForEach(productVM.lowStockProducts.prefix(2)) { product in
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)
                    Text("\(product.name) 재고 부족")
                        .font(.caption)
                    if let remaining = product.remainingQuantity {
                        Text("(\(remaining)개 남음)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }

            ForEach(productVM.expiringSoonProducts.prefix(2)) { product in
                HStack(spacing: 8) {
                    Image(systemName: product.isExpired ? "xmark.circle.fill" : "clock.fill")
                        .foregroundStyle(product.isExpired ? .red : .orange)
                        .font(.caption)
                    Text(product.isExpired
                         ? "\(product.name) 유통기한 만료"
                         : "\(product.name) 유통기한 임박")
                        .font(.caption)
                    Spacer()
                }
            }
        }
        .padding(10)
        .background(Color.orange.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
    }

    // MARK: - Product List

    private var productList: some View {
        List {
            if !productVM.activeProducts.isEmpty {
                Section("사용 중 (\(productVM.activeProducts.count))") {
                    ForEach(productVM.activeProducts) { product in
                        NavigationLink {
                            ProductDetailView(product: product)
                        } label: {
                            ProductRowView(product: product)
                        }
                    }
                    .onDelete { indexSet in
                        Task {
                            guard let userId = authVM.currentUserId else { return }
                            for index in indexSet {
                                await productVM.deleteProduct(
                                    productVM.activeProducts[index], userId: userId
                                )
                            }
                        }
                    }
                }
            }

            if !productVM.inactiveProducts.isEmpty {
                Section("사용 완료 (\(productVM.inactiveProducts.count))") {
                    ForEach(productVM.inactiveProducts) { product in
                        NavigationLink {
                            ProductDetailView(product: product)
                        } label: {
                            ProductRowView(product: product)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let title: String
    var icon: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon)
                        .font(.caption2)
                }
                Text(title)
                    .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor.opacity(0.15) : Color(.systemGray6))
            .foregroundStyle(isSelected ? Color.accentColor : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Product Row

struct ProductRowView: View {
    let product: BabyProduct

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: product.category.icon)
                .font(.title3)
                .foregroundStyle(product.isActive ? .primary : .secondary)
                .frame(width: 36, height: 36)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(product.name)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)

                    if product.isLowStock {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }

                HStack(spacing: 6) {
                    if let brand = product.brand {
                        Text(brand)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let size = product.size {
                        Text(size)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }

                    if let reaction = product.babyReaction {
                        Text(reaction.emoji)
                            .font(.caption)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                if let remaining = product.remainingQuantity, let total = product.quantity {
                    Text("\(remaining)/\(total)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(product.isLowStock ? .orange : .secondary)
                }

                if let price = product.priceText {
                    Text(price)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .opacity(product.isActive ? 1 : 0.6)
    }
}

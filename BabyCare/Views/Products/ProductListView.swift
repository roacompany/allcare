import SwiftUI

struct ProductListView: View {
    @Environment(ProductViewModel.self) private var productVM
    @Environment(PurchaseViewModel.self) private var purchaseVM
    @Environment(AuthViewModel.self) private var authVM
    @Environment(BabyViewModel.self) private var babyVM

    @State private var safariURL: URL?
    @State private var showSafari = false

    private var babyAgeMonths: Int {
        guard let baby = babyVM.selectedBaby else { return 0 }
        return Calendar.current.dateComponents([.month], from: baby.birthDate, to: Date()).month ?? 0
    }

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
                let reorderAlerts = purchaseVM.productsNeedingReorder(from: productVM.activeProducts)
                if !productVM.lowStockProducts.isEmpty || !productVM.expiringSoonProducts.isEmpty || !reorderAlerts.isEmpty {
                    alertsBanner
                }

                // Product list
                if productVM.filteredProducts.isEmpty && !productVM.isLoading {
                    ScrollView {
                        VStack(spacing: 20) {
                            EmptyStateView(
                                icon: "bag.fill",
                                title: "등록된 용품 없음",
                                message: "아기 용품을 등록하고 관리해보세요",
                                actionTitle: "용품 추가"
                            ) {
                                productVM.showAddProduct = true
                            }
                            .padding(.top, 40)

                            recommendationSection
                            popularSection
                        }
                    }
                } else {
                    productList
                }
            }
            .navigationTitle("용품 관리")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        AnalyticsService.shared.trackEvent(AnalyticsEvents.productView, parameters: [AnalyticsParams.actionType: "add"])
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
            .sheet(isPresented: $showSafari) {
                if let url = safariURL {
                    SafariView(url: url).ignoresSafeArea()
                }
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
                        Text("(\(remaining)\(product.effectiveUnit.displayName) 남음)")
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

            let reorderAlerts = purchaseVM.productsNeedingReorder(from: productVM.activeProducts)
            ForEach(reorderAlerts.prefix(2)) { product in
                let isOverdue = purchaseVM.nextReorderDate(for: product.id).map { $0 < Date() } ?? false
                HStack(spacing: 8) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .foregroundStyle(isOverdue ? .red : .orange)
                        .font(.caption)
                    Text(isOverdue
                         ? "\(product.name) 재주문 시기 초과"
                         : "\(product.name) 재주문 시기 임박")
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

    // MARK: - Recommendation Section

    private var recommendationSection: some View {
        let recs = productVM.ageBasedRecommendations(ageInMonths: babyAgeMonths)
        return Group {
            if !recs.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Label(
                        NSLocalizedString("product.recommend.section.title", comment: ""),
                        systemImage: "sparkles"
                    )
                    .font(.headline)
                    .foregroundStyle(AppColors.primaryAccent)
                    .padding(.horizontal)

                    if babyVM.selectedBaby != nil {
                        Text(
                            String(
                                format: NSLocalizedString("product.recommend.age.label", comment: ""),
                                babyAgeMonths
                            )
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                    }

                    VStack(spacing: 8) {
                        ForEach(recs.prefix(5)) { rec in
                            ProductRecommendationCard(recommendation: rec) { url in
                                safariURL = url
                                showSafari = true
                            }
                            .padding(.horizontal)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Popular Section

    private var popularSection: some View {
        let popular = productVM.popularCatalogProducts(limit: 5)
        return PopularProductsSection(popularProducts: popular) { url in
            safariURL = url
            showSafari = true
        }
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
                    .onDelete { indexSet in
                        Task {
                            guard let userId = authVM.currentUserId else { return }
                            for index in indexSet {
                                let product = productVM.inactiveProducts[index]
                                await productVM.deleteProduct(product, userId: userId)
                            }
                        }
                    }
                }
            }

            // 추천 섹션 (리스트 맨 아래)
            let recs = productVM.ageBasedRecommendations(ageInMonths: babyAgeMonths)
            if !recs.isEmpty {
                Section(
                    header: Label(
                        NSLocalizedString("product.recommend.section.title", comment: ""),
                        systemImage: "sparkles"
                    )
                ) {
                    ForEach(recs.prefix(5)) { rec in
                        ProductRecommendationCard(recommendation: rec) { url in
                            safariURL = url
                            showSafari = true
                        }
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        .listRowBackground(Color.clear)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

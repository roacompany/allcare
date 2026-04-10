import SwiftUI

extension AddProductView {

    // MARK: - Catalog mode

    var catalogModeView: some View {
        VStack(spacing: 0) {
            EmptyView()
                .task {
                    if productVM.catalog.isEmpty && !productVM.isCatalogLoading {
                        await productVM.loadCatalog()
                    }
                }
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

    // MARK: - Sub-views

    @ViewBuilder
    func categoryChip(_ cat: BabyProduct.ProductCategory?, label: String) -> some View {
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
    func catalogRow(_ item: CatalogProduct) -> some View {
        HStack(spacing: 12) {
            if let imageURL = item.imageURL {
                CachedAsyncImage(
                    url: imageURL,
                    size: CGSize(width: 44, height: 44)
                ) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.accentColor.opacity(0.1))
                        Image(systemName: categoryIcon(for: item.category))
                            .foregroundStyle(Color.accentColor)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.accentColor.opacity(0.1))
                        .frame(width: 44, height: 44)
                    Image(systemName: categoryIcon(for: item.category))
                        .foregroundStyle(Color.accentColor)
                }
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
    var catalogLoadingOrEmpty: some View {
        VStack(spacing: 12) {
            if productVM.isCatalogLoading {
                ProgressView()
                Text("카탈로그를 불러오는 중...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: "tray")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("카탈로그가 비어있습니다")
                    .font(.subheadline.weight(.medium))
                if productVM.catalogError != nil {
                    Text("카탈로그를 불러올 수 없습니다")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                Text("아래 직접 입력하기로 추가하세요.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("다시 시도") {
                    Task { await productVM.loadCatalog() }
                }
                .font(.caption)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 60)
    }

    @ViewBuilder
    var catalogNoResults: some View {
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
}

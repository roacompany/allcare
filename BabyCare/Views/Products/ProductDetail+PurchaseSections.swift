import SwiftUI

extension ProductDetailView {
    @ViewBuilder
    var purchaseSections1: some View {
            // 구매 관리
            Section("구매 관리") {
                Button {
                    if let url = CoupangAffiliateService.searchURL(for: product) {
                        safariURL = url
                        showSafari = true
                    }
                } label: {
                    Label("쿠팡에서 검색", systemImage: "magnifyingglass")
                }

                Button {
                    showAddPurchase = true
                } label: {
                    Label {
                        Text("구매 기록 추가")
                    } icon: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.green)
                    }
                }

                let productRecords = purchaseVM.recordsForProduct(product.id)
                if !productRecords.isEmpty {
                    NavigationLink {
                        productPurchaseHistory(productRecords)
                    } label: {
                        Label {
                            HStack {
                                Text("구매 이력")
                                Spacer()
                                Text("\(productRecords.count)건")
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundStyle(.purple)
                        }
                    }
                }

                if let avgDays = purchaseVM.averageReorderDays(for: product.id) {
                    HStack {
                        Label("평균 재주문 주기", systemImage: "calendar.badge.clock")
                        Spacer()
                        Text("약 \(avgDays)일")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Low stock banner
            if product.isLowStock {
                Section {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("재고가 부족합니다")
                                .font(.subheadline.weight(.medium))
                            if let remaining = product.remainingQuantity {
                                Text("\(remaining)개 남음")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(Color.orange.opacity(0.08))
            }
    }

    @ViewBuilder
    var purchaseSections2: some View {
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
    }

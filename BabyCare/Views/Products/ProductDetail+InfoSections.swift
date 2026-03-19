import SwiftUI

extension ProductDetailView {
    @ViewBuilder
    var infoSections: some View {
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
                                Text("\(remaining)개 남음 — 아래에서 쿠팡 검색 또는 구매 기록을 추가하세요")
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
}

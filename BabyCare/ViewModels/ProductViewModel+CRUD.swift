import Foundation
import UserNotifications

@MainActor
extension ProductViewModel {
    // MARK: - CRUD

    func loadProducts(userId: String) async {
        isLoading = true
        do {
            products = try await firestoreService.fetchProducts(userId: userId)
        } catch {
            errorMessage = "용품 목록을 불러오지 못했습니다."
        }
        isLoading = false
    }

    func addProduct(userId: String) async {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "용품 이름을 입력해주세요."
            return
        }

        var product = BabyProduct(
            babyId: selectedBabyId,
            name: name.trimmingCharacters(in: .whitespaces),
            brand: brand.isEmpty ? nil : brand.trimmingCharacters(in: .whitespaces),
            category: category,
            purchaseDate: hasPurchaseDate ? purchaseDate : nil,
            purchasePrice: Int(purchasePrice),
            purchaseStore: purchaseStore.isEmpty ? nil : purchaseStore,
            quantity: Int(quantity),
            remainingQuantity: Int(quantity),
            quantityUnit: quantityUnit,
            size: size.isEmpty ? nil : size,
            rating: rating,
            babyReaction: babyReaction,
            allergyNote: allergyNote.isEmpty ? nil : allergyNote,
            note: note.isEmpty ? nil : note,
            isActive: isActive,
            expiryDate: hasExpiry ? expiryDate : nil,
            reorderReminder: reorderReminder,
            reorderThreshold: Int(reorderThreshold)
        )
        if let catalogProduct = selectedCatalogProduct {
            product.catalogId = catalogProduct.id
            product.coupangURL = catalogProduct.coupangURL
        }

        do {
            try await firestoreService.saveProduct(product, userId: userId)
            products.insert(product, at: 0)
            resetForm()
            showAddProduct = false
        } catch {
            errorMessage = "용품 추가에 실패했습니다."
        }
    }

    func updateProduct(_ product: BabyProduct, userId: String) async {
        guard let index = products.firstIndex(where: { $0.id == product.id }) else { return }

        let backup = products[index]
        var updated = product
        updated.updatedAt = Date()
        products[index] = updated // 낙관적 업데이트

        do {
            try await firestoreService.saveProduct(updated, userId: userId)
        } catch {
            products[index] = backup // 롤백
            errorMessage = "수정에 실패했습니다: \(error.localizedDescription)"
        }
    }

    func useProduct(_ product: BabyProduct, amount: Int, userId: String) async {
        guard let remaining = product.remainingQuantity else { return }
        let newRemaining = max(0, remaining - amount)

        var updated = product
        updated.remainingQuantity = newRemaining
        updated.updatedAt = Date()
        if newRemaining == 0 {
            updated.isActive = false
        }

        await updateProduct(updated, userId: userId)

        // 재구매 알림 (업데이트 성공 후에만)
        if updated.isLowStock && updated.reorderReminder {
            let content = UNMutableNotificationContent()
            content.title = "재구매 알림"
            content.body = "\(product.name) 재고가 부족합니다. (\(newRemaining)\(product.effectiveUnit.displayName) 남음)"
            content.sound = .default
            let request = UNNotificationRequest(
                identifier: "reorder-\(product.id)",
                content: content,
                trigger: nil
            )
            do {
                try await UNUserNotificationCenter.current().add(request)
            } catch {
                // 알림 실패는 치명적이지 않으므로 경고만
                errorMessage = "재구매 알림 설정에 실패했습니다."
            }
        }
    }

    func deleteProduct(_ product: BabyProduct, userId: String) async {
        let backup = products
        products.removeAll { $0.id == product.id }

        do {
            try await firestoreService.deleteProduct(product.id, userId: userId)
        } catch {
            products = backup // 롤백
            errorMessage = "삭제에 실패했습니다."
        }
    }

    func toggleActive(_ product: BabyProduct, userId: String) async {
        var updated = product
        updated.isActive.toggle()
        await updateProduct(updated, userId: userId)
    }

    /// 활동 타입에 해당하는 용품 카테고리
    func categoryForActivity(_ type: Activity.ActivityType) -> BabyProduct.ProductCategory? {
        switch type {
        case .feedingBottle: .formula
        case .feedingSolid, .feedingSnack: .babyFood
        case .diaperWet, .diaperDirty, .diaperBoth: .diaper
        case .bath: .bath
        case .medication: .medicine
        default: nil
        }
    }

    /// 해당 카테고리의 활성 재고 용품 목록
    func availableProducts(for category: BabyProduct.ProductCategory) -> [BabyProduct] {
        products.filter { $0.category == category && $0.isActive && ($0.remainingQuantity ?? 0) > 0 }
    }

    /// 활동 기록에 따른 용품 재고 자동 차감 (용품이 1개면 자동, 없으면 스킵)
    /// - recordedAmount: 기록에서 입력한 실제 양 (ml/g). nil이면 기본 1개 차감.
    /// 반환값: 선택이 필요한 용품 목록 (2개 이상일 때). nil이면 처리 완료.
    @discardableResult
    func deductStockForActivity(_ type: Activity.ActivityType, userId: String, recordedAmount: Int? = nil) async -> [BabyProduct]? {
        guard let category = categoryForActivity(type) else { return nil }
        let candidates = availableProducts(for: category)

        if candidates.count == 1 {
            let amount = recordedAmount ?? candidates[0].effectiveUnit.stepAmount
            await useProduct(candidates[0], amount: amount, userId: userId)
            return nil
        } else if candidates.count > 1 {
            return candidates // UI에서 선택 필요
        }
        return nil // 재고 없음
    }

    /// 특정 용품에서 직접 차감 (사용자가 선택한 경우)
    /// - recordedAmount: 기록에서 입력한 실제 양. nil이면 기본 단위 차감.
    func deductFromProduct(_ product: BabyProduct, userId: String, recordedAmount: Int? = nil) async {
        let amount = recordedAmount ?? product.effectiveUnit.stepAmount
        await useProduct(product, amount: amount, userId: userId)
    }

    func resetForm() {
        name = ""
        brand = ""
        category = .diaper
        purchaseDate = Date()
        hasPurchaseDate = true
        purchasePrice = ""
        purchaseStore = ""
        quantity = ""
        quantityUnit = .count
        size = ""
        rating = nil
        babyReaction = nil
        allergyNote = ""
        note = ""
        isActive = true
        expiryDate = nil
        hasExpiry = false
        reorderReminder = false
        reorderThreshold = ""
        selectedBabyId = nil
        selectedCatalogProduct = nil
        errorMessage = nil
    }
}

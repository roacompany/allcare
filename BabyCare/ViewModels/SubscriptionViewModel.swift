import Foundation
import StoreKit

@MainActor @Observable
final class SubscriptionViewModel {
    var product: Product?
    var premiumStatus = PremiumStatus()
    var isLoading = false
    var isLoadingProduct = false
    private var didSetup = false
    var errorMessage: String?

    private let productID = "com.roacompany.allcare.premium.monthly"
    private var userId: String?
    private let premiumService = PremiumService.shared

    // MARK: - Setup

    func setup(userId: String) async {
        guard !didSetup else { return }
        didSetup = true
        self.userId = userId
        async let productLoad: Void = loadProduct()
        async let statusLoad: Void = loadStatus()
        _ = await (productLoad, statusLoad)
        listenTransactions()
    }

    // MARK: - 상품 로드

    private func loadProduct() async {
        isLoadingProduct = true
        do {
            let products = try await withThrowingTaskGroup(of: [Product].self) { group in
                group.addTask {
                    try await Product.products(for: [self.productID])
                }
                group.addTask {
                    try await Task.sleep(for: .seconds(8))
                    return [] // 타임아웃 시 빈 배열 반환 (throw 대신)
                }
                // 먼저 완료된 결과 사용
                if let result = try await group.next() {
                    group.cancelAll()
                    return result
                }
                return []
            }
            product = products.first
            if product == nil {
                errorMessage = "구독 상품을 불러올 수 없습니다. 네트워크를 확인해주세요."
            }
        } catch {
            errorMessage = "상품 정보를 불러오지 못했습니다."
        }
        isLoadingProduct = false
    }

    // MARK: - Firestore 상태 로드

    private func loadStatus() async {
        guard let userId else { return }
        do {
            var status = try await premiumService.fetchStatus(userId: userId)
            // 만료 체크
            if let expiry = status.subscriptionExpiry, expiry < Date() {
                status.isPremium = false
                try? await premiumService.saveStatus(status, userId: userId)
            }
            premiumStatus = status
        } catch {
            premiumStatus = PremiumStatus()
        }
        await verifyCurrentEntitlements()
    }

    // MARK: - 상품 재로드 (사용자 재시도)

    func retryLoadProduct() async {
        guard !isLoadingProduct else { return }
        errorMessage = nil
        await loadProduct()
    }

    // MARK: - 구매

    func purchase() async {
        guard let product else {
            errorMessage = "상품 정보를 불러오는 중입니다."
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await handleTransaction(transaction)
                await transaction.finish()
            case .userCancelled:
                break
            case .pending:
                errorMessage = "결제 승인 대기 중입니다."
            @unknown default:
                break
            }
        } catch {
            errorMessage = "구매에 실패했습니다."
        }
    }

    // MARK: - 무료 체험 사용

    func useTrial() async {
        guard let userId, premiumStatus.canUseTrial else { return }
        do {
            premiumStatus = try await premiumService.incrementTrial(userId: userId)
        } catch {
            errorMessage = "체험 사용 처리에 실패했습니다."
        }
    }

    // MARK: - 구독 복원

    func restore() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await AppStore.sync()
            await verifyCurrentEntitlements()
        } catch {
            errorMessage = "복원에 실패했습니다."
        }
    }

    // MARK: - Transaction 리스너

    private func listenTransactions() {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                do {
                    let transaction = try await self.checkVerified(result)
                    await self.handleTransaction(transaction)
                    await transaction.finish()
                } catch {}
            }
        }
    }

    // MARK: - 현재 구독 검증

    private func verifyCurrentEntitlements() async {
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                await handleTransaction(transaction)
            } catch {}
        }
    }

    // MARK: - 트랜잭션 처리

    private func handleTransaction(_ transaction: Transaction) async {
        guard let userId else { return }
        let isActive = transaction.revocationDate == nil
            && (transaction.expirationDate ?? .distantFuture) > Date()
        do {
            if isActive {
                try await premiumService.setSubscribed(userId: userId, expiry: transaction.expirationDate)
                premiumStatus.isPremium = true
                premiumStatus.subscriptionExpiry = transaction.expirationDate
            } else {
                try await premiumService.setExpired(userId: userId)
                premiumStatus.isPremium = false
                premiumStatus.subscriptionExpiry = nil
            }
        } catch {}
    }

    // MARK: - 검증 헬퍼

    nonisolated private func checkVerified<T: Sendable>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified: throw SubscriptionError.failedVerification
        case .verified(let value): return value
        }
    }

    enum SubscriptionError: Error { case failedVerification }
}

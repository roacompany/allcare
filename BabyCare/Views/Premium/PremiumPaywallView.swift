import SwiftUI
import StoreKit

struct PremiumPaywallView: View {
    @Environment(SubscriptionViewModel.self) private var subscriptionVM
    @Environment(\.dismiss) private var dismiss

    private let features: [(String, String, String)] = [
        ("waveform.and.magnifyingglass", "병원 방문 AI 리포트", "방문 전 아기 기록을 자동 분석해 의사에게 물어볼 내용을 정리해드려요"),
        ("checklist", "맞춤 질문 체크리스트", "AI가 생성한 질문을 체크하며 병원에서 빠짐없이 확인하세요"),
        ("bell.badge.fill", "방문 전날 알림", "예약일 하루 전 리포트 준비 완료 알림을 보내드려요"),
        ("clock.arrow.circlepath", "리포트 히스토리", "이전 방문 리포트를 언제든 다시 볼 수 있어요"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    // 헤더
                    VStack(spacing: 12) {
                        Image(systemName: "star.circle.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(.yellow)
                            .shadow(color: .yellow.opacity(0.3), radius: 12)

                        Text("베이비케어 프리미엄")
                            .font(.title.bold())

                        Text("아기 건강 관리를 한 단계 더\n스마트하게")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 8)

                    // 기능 목록
                    VStack(spacing: 0) {
                        ForEach(features, id: \.0) { icon, title, desc in
                            HStack(alignment: .top, spacing: 16) {
                                Image(systemName: icon)
                                    .font(.title3)
                                    .foregroundStyle(.pink)
                                    .frame(width: 32)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(title)
                                        .font(.subheadline.weight(.semibold))
                                    Text(desc)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 20)

                            if icon != features.last?.0 {
                                Divider().padding(.leading, 68)
                            }
                        }
                    }
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)

                    // 가격 & 구매 버튼
                    VStack(spacing: 12) {
                        if let product = subscriptionVM.product {
                            Button {
                                Task { await subscriptionVM.purchase() }
                            } label: {
                                HStack {
                                    if subscriptionVM.isLoading {
                                        ProgressView().tint(.white)
                                    } else {
                                        Text("월 \(product.displayPrice) 구독 시작")
                                            .font(.headline)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    LinearGradient(
                                        colors: [.pink, .pink.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .disabled(subscriptionVM.isLoading)
                        } else if subscriptionVM.isLoadingProduct {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(.secondary.opacity(0.2))
                                .frame(height: 54)
                                .overlay(ProgressView())
                        } else {
                            // 상품 로드 실패 (심사 전/네트워크 오류)
                            VStack(spacing: 8) {
                                Button {
                                    Task { await subscriptionVM.retryLoadProduct() }
                                } label: {
                                    HStack {
                                        Image(systemName: "arrow.clockwise")
                                        Text("구독 상품 다시 불러오기")
                                    }
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(Color.secondary.opacity(0.3))
                                    .foregroundStyle(.primary)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                }

                                Text("구독 상품을 불러오지 못했습니다. 네트워크 연결을 확인 후 다시 시도해주세요.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                        }

                        Button {
                            Task { await subscriptionVM.restore() }
                        } label: {
                            Text("구매 복원")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal)

                    // 안내 문구
                    VStack(spacing: 4) {
                        Text("구독은 언제든지 취소할 수 있습니다.")
                        Text("iTunes 계정으로 청구되며 갱신 24시간 전 자동 결제됩니다.")
                    }
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
                .frame(maxWidth: 500)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") { dismiss() }
                }
            }
            .alert("오류", isPresented: .init(get: { subscriptionVM.errorMessage != nil }, set: { if !$0 { subscriptionVM.errorMessage = nil } })) {
                Button("확인") { subscriptionVM.errorMessage = nil }
            } message: {
                Text(subscriptionVM.errorMessage ?? "")
            }
            .onChange(of: subscriptionVM.premiumStatus.isPremium) { _, isPremium in
                if isPremium { dismiss() }
            }
        }
    }
}

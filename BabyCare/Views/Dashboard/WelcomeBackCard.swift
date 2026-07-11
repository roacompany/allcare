import SwiftUI

/// 웰컴백 카드 (UX Clean Sweep C5) — 복귀 공백을 환영으로 연결. 오늘 기록이 생기면 자동 소멸.
struct WelcomeBackCard: View {
    let gapDays: Int

    var body: some View {
        HStack(spacing: 12) {
            Text("👋")
                .font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(gapDays)일 만에 오셨네요, 반가워요")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text("가볍게 하나만 기록해도 패턴이 다시 이어져요.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(AppColors.pastelMint.opacity(0.35))
        )
        .accessibilityElement(children: .combine)
        .onAppear {
            AnalyticsService.shared.trackEvent(AnalyticsEvents.welcomeBackShown)
        }
    }
}

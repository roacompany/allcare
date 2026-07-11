import SwiftUI

/// 위젯 설치 유도 카드 (UX Clean Sweep C2).
/// 노출 조건은 WidgetPromoPolicy가 판정. 닫기는 영구 해제(@AppStorage — 기기 UI 상태, 사용자 데이터 아님).
struct WidgetPromoCard: View {
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "square.grid.2x2")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.primaryAccent)
                Text("위젯으로 더 빠르게")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("위젯 안내 닫기")
            }

            Text("홈 화면 위젯을 추가하면 앱을 열지 않아도 다음 수유 시간과 오늘 요약을 바로 볼 수 있어요.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("홈 화면을 길게 누르고 + 버튼 → 베이비케어를 검색해 보세요.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(AppColors.primaryAccent.opacity(0.06))
        )
        .onAppear {
            AnalyticsService.shared.trackEvent(AnalyticsEvents.widgetPromoShown)
        }
    }
}

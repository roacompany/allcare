import SwiftUI

/// 파트너 초대 유도 카드 (UX Clean Sweep C3).
/// 노출 조건은 PartnerInvitePromoPolicy가 판정. 탭 → 가족 공유(초대) 화면 push.
struct PartnerInvitePromoCard: View {
    let onDismiss: () -> Void

    var body: some View {
        NavigationLink {
            FamilySharingView()
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "person.2")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.primaryAccent)
                    Text("함께 기록해요")
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
                    .accessibilityLabel("초대 안내 닫기")
                }

                Text("가족을 초대하면 기록을 함께 보고 남길 수 있어요. 교대할 때 놓치는 순간이 없어져요.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("탭해서 초대 코드 만들기")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(AppColors.primaryAccent)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(AppColors.primaryAccent.opacity(0.06))
            )
        }
        .buttonStyle(.plain)
        .simultaneousGesture(TapGesture().onEnded {
            AnalyticsService.shared.trackEvent(AnalyticsEvents.partnerInvitePromoTapped)
        })
        .onAppear {
            AnalyticsService.shared.trackEvent(AnalyticsEvents.partnerInvitePromoShown)
        }
    }
}

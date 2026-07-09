import SwiftUI

/// 첫 기록 가이드 카드 (이탈 방지 P0-1).
/// 노출 조건은 FirstRecordGuidePolicy가 판정하고, 탭 액션은 대시보드 quickSave 경로를 재사용한다.
struct FirstRecordGuideCard: View {
    let onTap: (Activity.ActivityType) -> Void

    @State private var didLogShown = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.primaryAccent)
                Text("기록을 시작해보세요")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
            }

            Text("가볍게 한 번이면 충분해요. 기록이 쌓이면 우리 아기의 패턴을 보여드려요.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                ForEach(FirstRecordGuidePolicy.guideTypes) { type in
                    Button {
                        AnalyticsService.shared.trackEvent(
                            AnalyticsEvents.firstRecordGuideTapped,
                            parameters: [AnalyticsParams.category: type.rawValue]
                        )
                        onTap(type)
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: type.icon)
                                .font(.body)
                                .foregroundStyle(Color(type.color))
                            Text(type.displayName)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(type.color).opacity(0.12))
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(type.displayName) 기록하기")
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(AppColors.primaryAccent.opacity(0.08))
        )
        .onAppear {
            guard !didLogShown else { return }
            didLogShown = true
            AnalyticsService.shared.trackEvent(AnalyticsEvents.firstRecordGuideShown)
        }
    }
}

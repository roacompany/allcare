import SwiftUI

/// 홈 여행 카드 — 다가오는(진행 중인) 여행 하나. 누르면 그 여행으로 여행 공간을 연다(설계 2026-11-05 §1).
struct TripHomeCard: View {
    let trip: Trip
    private let calendar = Calendar.current

    var body: some View {
        Button {
            TravelSpaceRouter.shared.open(tripId: trip.id)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "airplane")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.primaryAccent)
                    Text("여행 준비 · \(trip.city)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                Text("\(TripHeaderText.dates(trip, calendar: calendar)) · \(TripHeaderText.status(trip, today: Date(), calendar: calendar))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                Text("할 일·마감·하루 일정 보기")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(AppColors.primaryAccent)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(AppColors.primaryAccent.opacity(0.06))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

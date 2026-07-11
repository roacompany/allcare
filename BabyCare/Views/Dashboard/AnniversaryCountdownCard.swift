import SwiftUI

/// 기념일 카운트다운 카드 (UX Clean Sweep C4) — 임박(D-7) 시에만 노출, 지나면 자동 소멸.
struct AnniversaryCountdownCard: View {
    let anniversary: AnniversaryPolicy.Anniversary
    let babyName: String

    var body: some View {
        HStack(spacing: 12) {
            Text("🎂")
                .font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                if anniversary.dDay == 0 {
                    Text("오늘은 \(babyName)의 \(anniversary.title)이에요!")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text("축하해요 🎉")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(anniversary.title)까지 D-\(anniversary.dDay)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text("\(babyName)의 \(anniversary.title)이 다가와요")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(AppColors.pastelYellow.opacity(0.35))
        )
        .accessibilityElement(children: .combine)
    }
}

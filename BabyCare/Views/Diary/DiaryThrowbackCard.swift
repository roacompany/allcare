import SwiftUI

// MARK: - Diary Throwback Card

struct DiaryThrowbackCard: View {
    let throwback: ThrowbackEntry

    private var title: String {
        let key = "diary.throwback.title"
        return String(format: NSLocalizedString(key, comment: ""), throwback.monthsAgo)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                Label(title, systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                    .font(.subheadline.bold())
                    .foregroundStyle(AppColors.warmOrangeColor)
                Spacer()
                if let mood = throwback.entry.mood {
                    Text(mood.emoji)
                        .font(.title3)
                }
            }

            // Date
            Text(DateFormatters.fullDate.string(from: throwback.entry.date))
                .font(.caption)
                .foregroundStyle(.secondary)

            // Content preview
            Text(throwback.entry.content)
                .font(.callout)
                .lineLimit(4)
                .foregroundStyle(.primary)

            // Photos indicator
            if !throwback.entry.photoURLs.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "photo.fill")
                        .font(.caption2)
                    Text(String(format: NSLocalizedString("diary.throwback.photoCount", comment: ""), throwback.entry.photoURLs.count))
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppColors.warmOrangeColor.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
    }
}

import SwiftUI

// MARK: - FoodHistorySheet
// 식품별 시도 타임라인 시트: 첫 시도 → 재시도 → 안전 확인
// 기록 기반 분류 · 참고용

struct FoodHistorySheet: View {
    @Environment(HealthViewModel.self) private var healthVM
    @Environment(\.dismiss) private var dismiss

    let entry: FoodSafetyEntry

    private var events: [FoodHistoryEvent] {
        healthVM.foodHistory(for: entry.foodName)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Status summary header
                    statusHeader
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 20)

                    if events.isEmpty {
                        emptyState
                    } else {
                        timeline
                            .padding(.horizontal, 16)
                    }
                }
                .padding(.bottom, 24)
            }
            .navigationTitle(entry.foodName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(NSLocalizedString("food.history.sheet.close", comment: "")) {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Status Header

    private var statusHeader: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: entry.status.icon)
                        .foregroundStyle(Color(entry.status.colorName))
                    Text(entry.status.displayName)
                        .font(.headline)
                        .foregroundStyle(Color(entry.status.colorName))
                }
                Text(String(
                    format: NSLocalizedString("food.history.sheet.trialSummary", comment: ""),
                    entry.trialCount,
                    entry.reactionCount
                ))
                .font(.subheadline)
                .foregroundStyle(.secondary)

                if let firstDate = entry.firstTriedDate {
                    Text(String(
                        format: NSLocalizedString("food.history.sheet.firstTried", comment: ""),
                        DateFormatters.shortDate.string(from: firstDate)
                    ))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                }
            }
            Spacer()
            Image(systemName: entry.status.icon)
                .font(.system(size: 40))
                .foregroundStyle(Color(entry.status.colorName).opacity(0.3))
        }
        .padding(16)
        .background(Color(entry.status.colorName).opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text(NSLocalizedString("food.history.sheet.empty", comment: ""))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Timeline

    private var timeline: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(NSLocalizedString("food.history.sheet.timeline.title", comment: ""))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.bottom, 12)

            ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                HStack(alignment: .top, spacing: 12) {
                    // Timeline line + icon
                    VStack(spacing: 0) {
                        Circle()
                            .fill(eventColor(for: event.kind))
                            .frame(width: 28, height: 28)
                            .overlay {
                                Image(systemName: event.kind.icon)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.white)
                            }
                        if index < events.count - 1 {
                            Rectangle()
                                .fill(Color(.systemGray5))
                                .frame(width: 2)
                                .frame(minHeight: 32)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(event.kind.displayName)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(eventColor(for: event.kind))
                            Spacer()
                            Text(DateFormatters.shortDate.string(from: event.date))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let note = event.note, !note.isEmpty {
                            Text(note)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                    .padding(.bottom, index < events.count - 1 ? 20 : 0)
                }
            }
        }
    }

    private func eventColor(for kind: FoodHistoryEventKind) -> Color {
        switch kind {
        case .tried: return AppColors.solidColor
        case .reaction: return AppColors.coralColor
        case .safe: return AppColors.successColor
        }
    }
}

import SwiftUI

// MARK: - PumpedMilkStockView (유축 재고 화면, P5)
// 짜둔 모유 배치 목록 — 잔량·보관·짜낸 시각·유통기한·신선도 뱃지. 폐기 스와이프. 총 잔량 헤더.
// 6개월 창(freezer 포함) = activityVM.loadPumpInventory. 유통기한은 의료 감수 전 초안 → 면책 동반(safety.md).

struct PumpedMilkStockView: View {
    @Environment(ActivityViewModel.self) private var activityVM
    @Environment(BabyViewModel.self) private var babyVM
    @Environment(AuthViewModel.self) private var authVM
    @Environment(\.dismiss) private var dismiss

    /// 재고 → 먹이기 문 잇기 (유축 동선 B안, 2026-08-20) — 모유(병) 시트 직행.
    @State private var showFeedSheet = false

    private var state: PumpedMilkInventory.State { activityVM.fullPumpInventory }
    private var batches: [PumpedMilkInventory.Batch] {
        state.batches.filter { $0.remaining > 0 }   // 현재 재고 + 미폐기 만료분(정리 유도)
    }

    var body: some View {
        NavigationStack {
            Group {
                if batches.isEmpty {
                    ContentUnavailableView(
                        "유축한 모유가 없어요",
                        systemImage: "drop",
                        description: Text("‘유축’으로 기록하면 여기서 재고와 유통기한을 관리할 수 있어요.")
                    )
                } else {
                    List {
                        Section {
                            ForEach(batches) { batch in
                                batchRow(batch)
                                    .swipeActions {
                                        Button(role: .destructive) {
                                            Task { await discard(batch) }
                                        } label: {
                                            Label("폐기", systemImage: "trash")
                                        }
                                    }
                            }
                        } header: {
                            Text("총 \(Int(state.totalRemaining))mL")
                        } footer: {
                            Text("유통기한은 의료 감수 전 초안이라 참고용이에요. 색·냄새도 함께 확인해 주세요.")
                        }
                    }
                }
            }
            .navigationTitle("유축 재고")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                        .foregroundStyle(.secondary)
                }
            }
            .safeAreaInset(edge: .bottom) {
                // 재고에서 바로 소비 기록 — 유축(생산)과 그 사용(모유(병))을 한 공간에 (2026-08-20 A안 보조 문)
                if !batches.isEmpty {
                    Button { showFeedSheet = true } label: {
                        Label("먹이기 기록 — 모유(병)", systemImage: "waterbottle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(AppColors.feedingEmphasis)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                    .padding(.top, 10)
                    .padding(.bottom, 6)
                    .background(.thinMaterial)
                    .overlay(alignment: .top) { Divider() }
                }
            }
            .sheet(isPresented: $showFeedSheet) {
                UnifiedRecordSheet(type: .feedingBottle, contentPreset: .breastMilk)
            }
            .task { await load() }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func batchRow(_ batch: PumpedMilkInventory.Batch) -> some View {
        HStack(spacing: 12) {
            freshnessBadge(batch.freshness(now: Date()))
            VStack(alignment: .leading, spacing: 2) {
                Text("\(Int(batch.remaining))mL · \(batch.storage.displayName)")
                    .font(.subheadline.weight(.medium))
                Text("유축 시각 \(Self.dateText(batch.pumpedAt))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(expiryLabel(batch))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private func freshnessBadge(_ freshness: PumpedMilkInventory.Batch.Freshness) -> some View {
        let color: Color
        let text: String
        switch freshness {
        case .fresh: color = AppColors.sageColor; text = "신선"
        case .soon: color = AppColors.coralColor; text = "임박"
        case .expired: color = AppColors.neutralGray; text = "만료"
        }
        return Text(text)
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private func expiryLabel(_ batch: PumpedMilkInventory.Batch) -> String {
        switch batch.freshness(now: Date()) {
        case .expired: return "유통기한 지남"
        case .soon: return "곧 만료"
        case .fresh: return "\(Self.dateText(batch.expiresAt))까지"
        }
    }

    // MARK: - Actions

    private func load() async {
        guard let userId = ownerUserId(), let baby = babyVM.selectedBaby else { return }
        await activityVM.loadPumpInventory(userId: userId, babyId: baby.id)
    }

    private func discard(_ batch: PumpedMilkInventory.Batch) async {
        guard let userId = ownerUserId() else { return }
        await activityVM.discardPumpBatch(batch.id, userId: userId)
    }

    /// 가족 공유 owner path (authVM.currentUserId 직접 사용 금지 — safety.md).
    private func ownerUserId() -> String? {
        guard let currentUserId = authVM.currentUserId else { return nil }
        return babyVM.dataUserId(currentUserId: currentUserId) ?? currentUserId
    }

    private static func dateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M/d HH:mm"
        return formatter.string(from: date)
    }
}

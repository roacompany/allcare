import SwiftUI
import UIKit

/// AppState.badgePresenter.current을 관찰하여 신규 획득 배지를 상단 토스트로 노출.
/// 동시 다중 획득은 BadgePresenter FIFO 큐 + `.onChange` 순차 재트리거로 처리.
struct BadgeSnackbarView: View {
    @Bindable var presenter: BadgePresenter
    var onTap: () -> Void = {}

    @State private var visible = false
    @State private var dismissTask: Task<Void, Never>?
    private let haptic = UINotificationFeedbackGenerator()

    var body: some View {
        ZStack {
            if visible, let badge = presenter.current, let def = BadgeCatalog.definition(id: badge.id) {
                HStack(spacing: 12) {
                    Image(systemName: def.iconSFSymbol)
                        .font(.system(size: 28))
                        .foregroundStyle(AppColors.primaryAccent)
                        .frame(width: 44, height: 44)
                        .background(AppColors.cardBackground)
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(LocalizedStringKey("badge.snackbar.congrats"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(LocalizedStringKey(def.titleKey))
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.primary)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.regularMaterial)
                )
                .shadow(color: Color.black.opacity(0.12), radius: 8, y: 4)
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .transition(.move(edge: .top).combined(with: .opacity))
                .contentShape(Rectangle())
                .onTapGesture {
                    onTap()
                    finish()
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .allowsHitTesting(visible)
        .onChange(of: presenter.current?.id) { _, newId in
            handleCurrentChange(newId: newId)
        }
        .onAppear {
            if presenter.current != nil { show() }
        }
    }

    private func handleCurrentChange(newId: String?) {
        dismissTask?.cancel()
        guard newId != nil else {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                visible = false
            }
            return
        }
        if visible {
            // 이미 표시 중 — 살짝 닫고 다음 배지 표시 (0.3초 gap)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                visible = false
            }
            dismissTask = Task {
                try? await Task.sleep(nanoseconds: 300_000_000)
                guard !Task.isCancelled else { return }
                await MainActor.run { show() }
            }
        } else {
            show()
        }
    }

    private func show() {
        haptic.prepare()
        haptic.notificationOccurred(.success)
        withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
            visible = true
        }
        dismissTask?.cancel()
        dismissTask = Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run { finish() }
        }
    }

    private func finish() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            visible = false
        }
        presenter.dismiss()
    }
}

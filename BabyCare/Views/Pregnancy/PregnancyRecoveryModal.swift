import SwiftUI

// MARK: - PregnancyRecoveryModal
// 전환 중 중단된 pending orphan 복구 모달.
// 감지 조건: activePregnancy.transitionState == "pending" AND updatedAt > 30초 경과.
// DP-4: pending 1개만 이 모달. 2개+ 는 Settings 인라인 배너 (별도 구현).
//
// "이어서 완료" → PregnancyTransitionSheet 재사용 (사용자 명시적 탭 필수, 자동 retry 금지)
// "취소"        → Firestore transitionState 필드만 제거, 문서 삭제 절대 금지

struct PregnancyRecoveryModal: View {
    @Environment(PregnancyViewModel.self) private var pregnancyVM
    @Environment(AuthViewModel.self) private var authVM
    @Environment(\.dismiss) private var dismiss

    @State private var showTransitionSheet = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color.orange)

            VStack(spacing: 10) {
                Text("이전에 시작하신 전환이 멈춰 있어요.")
                    .font(.title3.weight(.bold))
                    .multilineTextAlignment(.center)

                Text("이어서 완료하시겠어요?")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)

            VStack(spacing: 12) {
                Button {
                    showTransitionSheet = true
                } label: {
                    Text("이어서 완료")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppColors.primaryAccent)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 32)

                Button(role: .cancel) {
                    handleCancel()
                } label: {
                    Text("취소")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .padding(.horizontal, 32)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showTransitionSheet, onDismiss: {
            // 시트 dismiss 후 pendingOrphan이 nil이면 모달도 자동으로 사라짐
            dismiss()
        }) {
            if let orphan = pregnancyVM.pendingOrphan ?? pregnancyVM.activePregnancy {
                PregnancyTransitionSheet(pregnancy: orphan)
            }
        }
        .interactiveDismissDisabled(true) // 스와이프 dismiss 방지 — 명시적 선택 강제
    }

    // MARK: - Cancel (Rollback)

    /// "취소": transitionState 필드만 제거하여 ongoing 복원.
    /// deleteActivePregnancy 사용 금지 — 사용자 데이터 보존 필수.
    private func handleCancel() {
        guard let userId = authVM.currentUserId else {
            dismiss()
            return
        }
        Task {
            await pregnancyVM.rollbackPendingTransition(userId: userId)
            dismiss()
        }
    }
}

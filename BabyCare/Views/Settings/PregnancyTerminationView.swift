import SwiftUI

// MARK: - PregnancyTerminationView
// 임신 종료 심층 경로 (설정 > 임신 관리 > 임신 종료).
// 유산/사산/임신중지 outcome 선택 → 확인 Alert → markTransitionPending → WriteBatch finalize.
// 출산 CTA는 PregnancyTransitionSheet(출산 완료 등록)에서 처리.

struct PregnancyTerminationView: View {
    @Environment(PregnancyViewModel.self) private var pregnancyVM
    @Environment(AuthViewModel.self) private var authVM
    @Environment(\.dismiss) private var dismiss

    // MARK: - UI State

    @State private var selectedOutcome: PregnancyOutcome = .miscarriage
    @State private var showConfirmAlert = false
    @State private var phase: TerminationPhase = .form

    private enum TerminationPhase {
        case form
        case success
        case failure(String)
    }

    // MARK: - Termination outcomes only

    private let terminationOutcomes: [PregnancyOutcome] = [
        .miscarriage, .stillbirth, .terminated
    ]

    // MARK: - Body

    var body: some View {
        Group {
            switch phase {
            case .form:
                formContent
            case .success:
                successContent
            case .failure(let message):
                failureContent(message: message)
            }
        }
        .navigationTitle("임신 종료")
        .navigationBarTitleDisplayMode(.inline)
        .alert(
            "임신 종료를 기록하시겠어요?",
            isPresented: $showConfirmAlert
        ) {
            Button("기록 진행", role: .destructive) {
                performTermination()
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("되돌리려면 설정 > 이전 임신에서 복구해야 합니다.")
        }
    }

    // MARK: - Form Content

    private var formContent: some View {
        Form {
            Section {
                HStack(spacing: 10) {
                    Image(systemName: "heart")
                        .foregroundStyle(.secondary)
                    Text("힘든 시간을 보내고 계신다면 진심으로 위로의 말씀을 드립니다. 기록은 언제든 이전 임신에서 확인하실 수 있습니다.")
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                }
                .padding(.vertical, 4)
            }
            .listRowBackground(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.secondary.opacity(0.08))
            )

            Section("종료 유형") {
                Picker("종료 유형", selection: $selectedOutcome) {
                    ForEach(terminationOutcomes, id: \.self) { outcome in
                        Text(outcome.displayName).tag(outcome)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }

            Section {
                Button {
                    showConfirmAlert = true
                } label: {
                    HStack {
                        Spacer()
                        Text("임신 종료")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.secondary.opacity(0.7))
                )
            }
        }
    }

    // MARK: - Success Content

    private var successContent: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("임신 기록이 저장되었습니다.")
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)

            Text("이전 임신에서 확인하실 수 있습니다.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Failure Content

    private func failureContent(message: String) -> some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "xmark.circle")
                .font(.system(size: 64))
                .foregroundStyle(.red)

            Text("기록에 실패했습니다.")
                .font(.title3.weight(.semibold))

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("다시 시도") {
                phase = .form
            }
            .buttonStyle(.borderedProminent)
            .tint(.secondary)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Termination Action

    private func performTermination() {
        guard let userId = authVM.currentUserId else { return }
        Task {
            do {
                try await pregnancyVM.terminatePregnancy(outcome: selectedOutcome, userId: userId)
                phase = .success
                try? await Task.sleep(for: .seconds(2))
                dismiss()
            } catch {
                phase = .failure(error.localizedDescription)
            }
        }
    }
}

import SwiftUI

// MARK: - RecordingView
// Main sheet presented when the user taps the "+" recording button.
// Shows category tabs (수유 / 수면 / 기저귀 / 건강) then sub-type options,
// then the relevant record form.

struct RecordingView: View {
    @Environment(ActivityViewModel.self) private var activityVM
    @Environment(BabyViewModel.self) private var babyVM
    @Environment(AuthViewModel.self) private var authVM
    @Environment(\.dismiss) private var dismiss

    /// 외부에서 초기 카테고리 주입 (딥링크용)
    var initialCategory: Activity.ActivityCategory?

    // Selected tab
    @State private var selectedCategory: Activity.ActivityCategory = .feeding

    // Selected feeding sub-type (defaults to breast)
    @State private var selectedFeedingType: Activity.ActivityType = .feedingBreast

    @State private var showCloseConfirm = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // ── Category tab bar ───────────────────────────────────────
                CategoryTabBar(
                    selected: $selectedCategory,
                    onChange: { _ in
                        // Stop any running timer when switching top-level category
                        if activityVM.isTimerRunning { _ = activityVM.stopTimer() }
                        activityVM.resetForm()
                    }
                )
                .padding(.horizontal)
                .padding(.top, 8)

                // ── Sub-type picker (feeding only) ─────────────────────────
                if selectedCategory == .feeding {
                    FeedingSubPicker(selected: $selectedFeedingType)
                        .padding(.horizontal)
                        .padding(.top, 12)
                }

                Divider()
                    .padding(.top, 12)

                // ── Record form ────────────────────────────────────────────
                Group {
                    switch selectedCategory {
                    case .feeding:
                        FeedingRecordView(
                            type: selectedFeedingType,
                            onSaved: { dismiss() }
                        )
                    case .sleep:
                        SleepRecordView(onSaved: { dismiss() })
                    case .diaper:
                        DiaperRecordView(onSaved: { dismiss() })
                    case .health:
                        HealthRecordView(onSaved: { dismiss() })
                    }
                }
                .id(selectedCategory) // re-render on tab switch
            }
            .navigationTitle(babyVM.selectedBaby.map { "\($0.name) 기록" } ?? "기록")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") {
                        if activityVM.isTimerRunning {
                            showCloseConfirm = true
                        } else {
                            activityVM.resetForm()
                            dismiss()
                        }
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .confirmationDialog(
                "타이머가 실행 중입니다",
                isPresented: $showCloseConfirm,
                titleVisibility: .visible
            ) {
                Button("닫기", role: .destructive) {
                    _ = activityVM.stopTimer()
                    activityVM.resetForm()
                    dismiss()
                }
                Button("취소", role: .cancel) {}
            } message: {
                Text("닫으면 측정 중인 시간이 사라집니다.")
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
        .onAppear {
            if let initialCategory {
                selectedCategory = initialCategory
            }
            // Live Activity에 아기 이름 전달
            activityVM.currentBabyName = babyVM.selectedBaby?.name ?? "아기"
        }
        .alert("오류", isPresented: Binding(
            get: { activityVM.errorMessage != nil },
            set: { if !$0 { activityVM.errorMessage = nil } }
        )) {
            Button("확인", role: .cancel) { }
        } message: {
            Text(activityVM.errorMessage ?? "")
        }
    }
}

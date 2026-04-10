import SwiftUI

// MARK: - RecordingView
// Main sheet presented when the user taps the "+" recording button.
// Shows category tabs (수유 / 수면 / 기저귀 / 건강) then sub-type options,
// then the relevant record form.

struct RecordingView: View {
    @Environment(ActivityViewModel.self) private var activityVM
    @Environment(BabyViewModel.self) private var babyVM
    @Environment(AuthViewModel.self) private var authVM

    /// sheet dismiss — NavigationStack 밖에서 바인딩 주입
    @Binding var isPresented: Bool

    /// 외부에서 초기 카테고리 주입 (딥링크용)
    var initialCategory: Activity.ActivityCategory?

    // Selected tab
    @State private var selectedCategory: Activity.ActivityCategory = .feeding

    // Selected feeding sub-type (defaults to breast)
    @State private var selectedFeedingType: Activity.ActivityType = .feedingBreast

    @State private var showCloseConfirm = false
    @State private var showUnsavedDataConfirm = false
    @State private var savedMessage: String?

    // MARK: - Unsaved data check

    private var hasUnsavedData: Bool {
        !activityVM.temperatureInput.isEmpty
            || !activityVM.amount.isEmpty
            || !activityVM.foodName.isEmpty
            || !activityVM.medicationName.isEmpty
            || !activityVM.note.isEmpty
            || !activityVM.foodAmount.isEmpty
            || !activityVM.medicationDosage.isEmpty
    }

    // MARK: - Save success handler

    private func handleSaved() {
        AnalyticsService.shared.trackEvent(AnalyticsEvents.recordSave, parameters: [AnalyticsParams.category: selectedCategory.rawValue])
        // 위젯 데이터 동기화
        if let baby = babyVM.selectedBaby {
            activityVM.syncWidgetData(
                babyName: baby.name,
                babyAge: baby.ageText
            )
        }
        withAnimation {
            savedMessage = "기록이 저장되었습니다"
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            activityVM.resetForm()
            isPresented = false
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // ── Category tab bar ───────────────────────────────────────
                CategoryTabBar(
                    selected: $selectedCategory,
                    onChange: { _ in
                        // Stop any running timer when switching top-level category
                        if activityVM.isTimerRunning {
                            let elapsed = activityVM.elapsedTime
                            let minutes = Int(elapsed) / 60
                            let seconds = Int(elapsed) % 60
                            _ = activityVM.stopTimer()
                            withAnimation {
                                savedMessage = "타이머가 정지되었습니다 (\(minutes):\(String(format: "%02d", seconds)))"
                            }
                        }
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
                            onSaved: { handleSaved() }
                        )
                    case .sleep:
                        SleepRecordView(onSaved: { handleSaved() })
                    case .diaper:
                        DiaperRecordView(onSaved: { handleSaved() })
                    case .health:
                        HealthRecordView(onSaved: { handleSaved() })
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
                        } else if hasUnsavedData {
                            showUnsavedDataConfirm = true
                        } else {
                            activityVM.resetForm()
                            isPresented = false
                        }
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .overlay(alignment: .bottom) {
                if let msg = savedMessage {
                    Text(msg)
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(.bottom, 20)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .id(msg)
                }
            }
            .animation(.easeInOut, value: savedMessage)
            .confirmationDialog(
                "타이머가 실행 중입니다",
                isPresented: $showCloseConfirm,
                titleVisibility: .visible
            ) {
                Button("저장하고 닫기") {
                    let timerType = activityVM.activeTimerType
                    let duration = activityVM.stopTimer()
                    if duration > 0, let timerType {
                        Task {
                            guard let currentUserId = authVM.currentUserId,
                                  let babyId = babyVM.selectedBaby?.id else { return }
                            let dataUserId = babyVM.dataUserId(currentUserId: currentUserId) ?? currentUserId
                            await activityVM.saveActivity(userId: dataUserId, babyId: babyId, type: timerType)
                            activityVM.resetForm()
                            isPresented = false
                        }
                    } else {
                        activityVM.resetForm()
                        isPresented = false
                    }
                }
                Button("저장하지 않고 닫기", role: .destructive) {
                    _ = activityVM.stopTimer()
                    activityVM.resetForm()
                    isPresented = false
                }
                Button("취소", role: .cancel) {}
            } message: {
                Text("타이머를 저장하고 닫을 수 있습니다.")
            }
            .confirmationDialog(
                "저장하지 않고 닫을까요?",
                isPresented: $showUnsavedDataConfirm,
                titleVisibility: .visible
            ) {
                Button("닫기", role: .destructive) {
                    activityVM.resetForm()
                    isPresented = false
                }
                Button("취소", role: .cancel) {}
            } message: {
                Text("입력한 내용이 저장되지 않습니다.")
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
        .confirmationDialog("중복 기록", isPresented: Bindable(activityVM).showDuplicateWarning, titleVisibility: .visible) {
            Button("저장") {
                Task { await activityVM.pendingDuplicateSave?() }
            }
            Button("취소", role: .cancel) {
                activityVM.pendingDuplicateSave = nil
            }
        } message: {
            Text("비슷한 시간에 같은 기록이 있습니다. 저장할까요?")
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

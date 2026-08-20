import SwiftUI

// MARK: - SleepRecordView
// Sleep recording: large timer + sleep quality + sleep method + note.

struct SleepRecordView: View {
    @Environment(ActivityViewModel.self) private var activityVM
    @Environment(BabyViewModel.self) private var babyVM
    @Environment(AuthViewModel.self) private var authVM

    var onSaved: (() -> Void)? = nil

    @State private var isSaving = false

    // 액센트 = Activity 단일 소스(emphasisColor) — 수면은 홈 정본과 같은 페리윙클 계열 (기존 인디고 하드코딩 제거).
    private let accentColor = Color(Activity.ActivityType.sleep.emphasisColor)

    var body: some View {
        @Bindable var vm = activityVM

        ScrollView {
            VStack(spacing: 24) {
                // Header 제거 — 내비 제목 + 수면 탭이 이미 같은 정보 (3중 제목 해소, 2026-08-20 재작업)

                // ── Time adjustment ───────────────────────────────────────
                TimeAdjustmentSection(accentColor: accentColor, showEndTime: true)

                // ── Timer ──────────────────────────────────────────────────
                TimerView(type: .sleep, accentColor: accentColor)
                    .padding(.vertical, 8)

                // ── Sleep quality (별도 필드) ─────────────────────────────
                VStack(alignment: .leading, spacing: 10) {
                    Label("수면 상태", systemImage: "moon.stars.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)

                    HStack(spacing: 10) {
                        ForEach(Activity.SleepQualityType.allCases, id: \.self) { quality in
                            Button {
                                activityVM.sleepQuality = activityVM.sleepQuality == quality ? nil : quality
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: quality.icon)
                                        .font(.caption)
                                    Text(quality.displayName)
                                        .font(.caption.bold())
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    activityVM.sleepQuality == quality
                                        ? accentColor : accentColor.opacity(0.1)
                                )
                                .foregroundStyle(
                                    activityVM.sleepQuality == quality ? .white : accentColor
                                )
                                .clipShape(Capsule())
                            }
                            .animation(.spring(duration: 0.25), value: activityVM.sleepQuality)
                        }
                    }
                }
                .padding()
                .background(accentColor.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)

                // ── Sleep method (잠든 곳) ───────────────────────────
                VStack(alignment: .leading, spacing: 10) {
                    Label("잠든 곳", systemImage: "zzz")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)

                    FlowLayout(spacing: 8) {
                        ForEach(Activity.SleepMethodType.selectableCases, id: \.self) { method in
                            Button {
                                let newValue: Activity.SleepMethodType? = activityVM.sleepMethod == method ? nil : method
                                activityVM.sleepMethod = newValue
                                if let babyId = babyVM.selectedBaby?.id, let selected = newValue {
                                    UserDefaults.standard.set(selected.rawValue, forKey: lastMethodKey(babyId: babyId))
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: method.icon)
                                        .font(.caption)
                                    Text(method.displayName)
                                        .font(.caption.bold())
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    activityVM.sleepMethod == method
                                        ? accentColor : accentColor.opacity(0.1)
                                )
                                .foregroundStyle(
                                    activityVM.sleepMethod == method ? .white : accentColor
                                )
                                .clipShape(Capsule())
                            }
                            .animation(.spring(duration: 0.25), value: activityVM.sleepMethod)
                        }
                    }
                }
                .padding()
                .background(accentColor.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)

                // ── Note ───────────────────────────────────────────────────
                NoteField(note: $vm.note, accentColor: accentColor)
                    .padding(.horizontal)
                    .padding(.bottom, 12)
            }
            .padding(.top, 8)
        }
        .safeAreaInset(edge: .bottom) {
            SaveBar(isSaving: isSaving, color: accentColor, action: save)
        }
        .onAppear {
            AnalyticsService.shared.trackScreen(AnalyticsScreens.sleepRecording)
            if let babyId = babyVM.selectedBaby?.id,
               activityVM.sleepMethod == nil,
               let raw = UserDefaults.standard.string(forKey: lastMethodKey(babyId: babyId)),
               let method = Activity.SleepMethodType(rawValue: raw) {
                // deprecated 기본값(holding/nursing) 마이그레이션
                let migrated: Activity.SleepMethodType
                switch method {
                case .holding: migrated = .inArms
                case .nursing: migrated = .bed
                default: migrated = method
                }
                activityVM.sleepMethod = migrated
                if migrated != method {
                    UserDefaults.standard.set(migrated.rawValue, forKey: lastMethodKey(babyId: babyId))
                }
            }
        }
    }

    // MARK: - Actions

    private func lastMethodKey(babyId: String) -> String {
        "lastSleepMethod_\(babyId)"
    }

    private func save() {
        guard let currentUserId = authVM.currentUserId,
              let baby = babyVM.selectedBaby else { return }
        let dataUserId = babyVM.dataUserId(currentUserId: currentUserId) ?? currentUserId
        isSaving = true
        Task {
            await activityVM.saveActivity(userId: dataUserId, currentUserId: currentUserId, babyId: baby.id, type: .sleep)
            isSaving = false
            if activityVM.errorMessage == nil {
                // 저장 성공 후 발화 (시도≠성공 혼재 방지)
                AnalyticsService.shared.trackEvent(AnalyticsEvents.sleepRecordSave)
                onSaved?()
            }
        }
    }
}

#Preview {
    SleepRecordView()
        .environment(ActivityViewModel())
        .environment(BabyViewModel())
        .environment(AuthViewModel())
}

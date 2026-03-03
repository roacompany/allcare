import SwiftUI

// MARK: - SleepRecordView
// Sleep recording: large timer + optional note.

struct SleepRecordView: View {
    @Environment(ActivityViewModel.self) private var activityVM
    @Environment(BabyViewModel.self) private var babyVM
    @Environment(AuthViewModel.self) private var authVM

    var onSaved: (() -> Void)? = nil

    @State private var isSaving = false

    private let accentColor = Color(hex: "7B9FE8")  // indigo-ish pastel

    var body: some View {
        @Bindable var vm = activityVM

        ScrollView {
            VStack(spacing: 24) {

                // ── Header ─────────────────────────────────────────────────
                HStack(spacing: 10) {
                    Image(systemName: Activity.ActivityType.sleep.icon)
                        .font(.title2)
                        .foregroundStyle(accentColor)
                    Text("수면")
                        .font(.title3.bold())
                    Spacer()
                }
                .padding(.horizontal)

                // ── Timer ──────────────────────────────────────────────────
                TimerView(type: .sleep, accentColor: accentColor)
                    .padding(.vertical, 8)

                // ── 수면 상태 (별도 필드) ──────────────────────────────────
                VStack(alignment: .leading, spacing: 10) {
                    Label("수면 상태", systemImage: "moon.stars.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)

                    HStack(spacing: 10) {
                        ForEach(Activity.SleepQualityType.allCases, id: \.self) { quality in
                            Button {
                                withAnimation(.spring(duration: 0.25)) {
                                    activityVM.sleepQuality = activityVM.sleepQuality == quality ? nil : quality
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: quality.icon)
                                        .font(.caption)
                                    Text(quality.displayName)
                                        .font(.caption.bold())
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(activityVM.sleepQuality == quality ? accentColor : accentColor.opacity(0.1))
                                .foregroundStyle(activityVM.sleepQuality == quality ? .white : accentColor)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding()
                .background(accentColor.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)

                // ── 수면 장소 ────────────────────────────────────────────
                VStack(alignment: .leading, spacing: 10) {
                    Label("수면 장소", systemImage: "bed.double.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        ForEach(Activity.SleepLocationType.allCases, id: \.self) { location in
                            Button {
                                withAnimation(.spring(duration: 0.25)) {
                                    activityVM.sleepLocation = activityVM.sleepLocation == location ? nil : location
                                }
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: location.icon)
                                        .font(.body)
                                    Text(location.displayName)
                                        .font(.system(size: 11, weight: .semibold))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    activityVM.sleepLocation == location
                                        ? accentColor : accentColor.opacity(0.08)
                                )
                                .foregroundStyle(
                                    activityVM.sleepLocation == location ? .white : accentColor
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
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

                // ── Save ───────────────────────────────────────────────────
                SaveButton(isSaving: isSaving, color: accentColor, action: save)
                    .padding(.horizontal)
                    .padding(.bottom, 16)
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Actions

    private func save() {
        guard let userId = authVM.currentUserId,
              let baby = babyVM.selectedBaby else { return }
        isSaving = true
        Task {
            await activityVM.saveActivity(userId: userId, babyId: baby.id, type: .sleep)
            isSaving = false
            if activityVM.errorMessage == nil {
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

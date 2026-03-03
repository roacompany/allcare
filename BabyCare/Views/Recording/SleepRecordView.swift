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

                // ── Sleep quality hint ─────────────────────────────────────
                VStack(alignment: .leading, spacing: 10) {
                    Label("수면 상태", systemImage: "moon.stars.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)

                    HStack(spacing: 10) {
                        ForEach(SleepQuality.allCases) { quality in
                            QualityChip(
                                quality: quality,
                                isSelected: vm.note.hasPrefix(quality.rawValue),
                                color: accentColor
                            ) {
                                // Toggle tag at start of note
                                if vm.note.hasPrefix(quality.rawValue) {
                                    vm.note = String(vm.note.dropFirst(quality.rawValue.count))
                                        .trimmingCharacters(in: .whitespaces)
                                } else {
                                    // Remove any previous quality tag
                                    var cleaned = vm.note
                                    for q in SleepQuality.allCases {
                                        if cleaned.hasPrefix(q.rawValue) {
                                            cleaned = String(cleaned.dropFirst(q.rawValue.count))
                                                .trimmingCharacters(in: .whitespaces)
                                        }
                                    }
                                    vm.note = cleaned.isEmpty
                                        ? quality.rawValue
                                        : "\(quality.rawValue) \(cleaned)"
                                }
                            }
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

// MARK: - SleepQuality (local helper)

private enum SleepQuality: String, CaseIterable, Identifiable {
    case good   = "잘 잠"
    case fussy  = "뒤척임"
    case light  = "얕은 수면"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .good:  "moon.fill"
        case .fussy: "figure.walk"
        case .light: "cloud.moon.fill"
        }
    }
}

private struct QualityChip: View {
    let quality: SleepQuality
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: quality.icon)
                    .font(.caption)
                Text(quality.rawValue)
                    .font(.caption.bold())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? color : color.opacity(0.1))
            .foregroundStyle(isSelected ? .white : color)
            .clipShape(Capsule())
        }
        .animation(.spring(duration: 0.25), value: isSelected)
    }
}

#Preview {
    SleepRecordView()
        .environment(ActivityViewModel())
        .environment(BabyViewModel())
        .environment(AuthViewModel())
}

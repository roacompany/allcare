import SwiftUI

// MARK: - DiaperRecordView
// Diaper type selection with one-tap quick save.

struct DiaperRecordView: View {
    @Environment(ActivityViewModel.self) private var activityVM
    @Environment(BabyViewModel.self) private var babyVM
    @Environment(AuthViewModel.self) private var authVM

    var onSaved: (() -> Void)? = nil

    @State private var selectedDiaperType: Activity.ActivityType = .diaperWet
    @State private var isSaving = false

    private let accentColor = Color(hex: "85C1A3")   // sage green pastel

    private let diaperTypes: [(Activity.ActivityType, String, String)] = [
        (.diaperWet,   "소변",       "drop.fill"),
        (.diaperDirty, "대변",       "leaf.fill"),
        (.diaperBoth,  "소변+대변",  "humidity.fill"),
    ]

    var body: some View {
        @Bindable var vm = activityVM

        ScrollView {
            VStack(spacing: 24) {

                // ── Header ─────────────────────────────────────────────────
                HStack(spacing: 10) {
                    Image(systemName: "humidity.fill")
                        .font(.title2)
                        .foregroundStyle(accentColor)
                    Text("기저귀")
                        .font(.title3.bold())
                    Spacer()
                }
                .padding(.horizontal)

                // ── Type cards ─────────────────────────────────────────────
                VStack(spacing: 12) {
                    ForEach(diaperTypes, id: \.0) { (type, label, icon) in
                        DiaperTypeCard(
                            label: label,
                            icon: icon,
                            isSelected: selectedDiaperType == type,
                            color: cardColor(for: type)
                        ) {
                            withAnimation(.spring(duration: 0.25)) {
                                selectedDiaperType = type
                            }
                        }
                    }
                }
                .padding(.horizontal)

                // ── Note ───────────────────────────────────────────────────
                NoteField(note: $vm.note, accentColor: accentColor)
                    .padding(.horizontal)

                // ── Quick save ─────────────────────────────────────────────
                Button(action: quickSave) {
                    HStack(spacing: 10) {
                        if isSaving {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title3)
                            Text("바로 저장")
                                .font(.headline)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: accentColor.opacity(0.35), radius: 8, y: 4)
                }
                .disabled(isSaving)
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Actions

    private func quickSave() {
        guard let userId = authVM.currentUserId,
              let baby = babyVM.selectedBaby else { return }
        isSaving = true
        Task {
            // quickSave does not handle note; use saveActivity for note support
            await activityVM.saveActivity(
                userId: userId,
                babyId: baby.id,
                type: selectedDiaperType
            )
            isSaving = false
            onSaved?()
        }
    }

    private func cardColor(for type: Activity.ActivityType) -> Color {
        switch type {
        case .diaperWet:   Color(hex: "85C1A3")
        case .diaperDirty: Color(hex: "C1A585")
        default:           Color(hex: "A585C1")
        }
    }
}

// MARK: - DiaperTypeCard

private struct DiaperTypeCard: View {
    let label: String
    let icon: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(isSelected ? color : color.opacity(0.12))
                        .frame(width: 48, height: 48)
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(isSelected ? .white : color)
                }

                Text(label)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(isSelected ? color : .primary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(color)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? color.opacity(0.1) : Color(.systemBackground))
                    .shadow(
                        color: isSelected ? color.opacity(0.2) : .black.opacity(0.05),
                        radius: isSelected ? 8 : 4,
                        y: 2
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? color.opacity(0.4) : Color(.systemGray5), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    DiaperRecordView()
        .environment(ActivityViewModel())
        .environment(BabyViewModel())
        .environment(AuthViewModel())
}

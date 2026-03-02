import SwiftUI

// MARK: - FeedingRecordView
// Handles both breast and bottle (and solid / snack) feeding records.

struct FeedingRecordView: View {
    @Environment(ActivityViewModel.self) private var activityVM
    @Environment(BabyViewModel.self) private var babyVM
    @Environment(AuthViewModel.self) private var authVM

    let type: Activity.ActivityType
    var onSaved: (() -> Void)? = nil

    @State private var isSaving = false

    // Accent colour per sub-type
    private var accentColor: Color {
        switch type {
        case .feedingBreast:  .pink
        case .feedingBottle:  Color(hex: "7B9FE8")  // soft blue
        case .feedingSolid:   Color(hex: "F4A261")  // warm orange
        case .feedingSnack:   Color(hex: "7CB77E")  // sage green
        default:              .pink
        }
    }

    var body: some View {
        @Bindable var vm = activityVM

        ScrollView {
            VStack(spacing: 20) {

                // ── Type header ────────────────────────────────────────────
                HStack(spacing: 10) {
                    Image(systemName: type.icon)
                        .font(.title2)
                        .foregroundStyle(accentColor)
                    Text(type.displayName)
                        .font(.title3.bold())
                        .foregroundStyle(.primary)
                    Spacer()
                }
                .padding(.horizontal)

                // ── Timer (breast / bottle only) ───────────────────────────
                if type.needsTimer {
                    TimerView(type: type, accentColor: accentColor)
                        .padding(.vertical, 8)
                }

                // ── Breast side selector ───────────────────────────────────
                if type == .feedingBreast {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("수유 방향", systemImage: "arrow.left.arrow.right")
                            .font(.subheadline.bold())
                            .foregroundStyle(.secondary)

                        HStack(spacing: 12) {
                            ForEach(Activity.BreastSide.allCases, id: \.self) { side in
                                SideButton(
                                    side: side,
                                    isSelected: activityVM.selectedSide == side,
                                    color: accentColor
                                ) {
                                    activityVM.selectedSide = side
                                }
                            }
                        }
                    }
                    .padding()
                    .background(accentColor.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)
                }

                // ── Amount input (bottle / solid / snack) ──────────────────
                if type == .feedingBottle {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("섭취량 (ml)", systemImage: "drop.fill")
                            .font(.subheadline.bold())
                            .foregroundStyle(.secondary)

                        HStack {
                            TextField("0", text: $vm.amount)
                                .keyboardType(.numberPad)
                                .font(.system(size: 28, weight: .semibold, design: .rounded))
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)

                            Text("ml")
                                .font(.title3.bold())
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        // Quick-fill buttons
                        HStack(spacing: 8) {
                            ForEach([60, 80, 100, 120, 150, 180], id: \.self) { ml in
                                Button("\(ml)") {
                                    activityVM.amount = "\(ml)"
                                }
                                .font(.system(size: 13, weight: .medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    activityVM.amount == "\(ml)"
                                        ? accentColor
                                        : accentColor.opacity(0.1)
                                )
                                .foregroundStyle(
                                    activityVM.amount == "\(ml)" ? .white : accentColor
                                )
                                .clipShape(Capsule())
                            }
                        }
                    }
                    .padding()
                    .background(accentColor.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)
                }

                // ── Note ───────────────────────────────────────────────────
                NoteField(note: $vm.note, accentColor: accentColor)
                    .padding(.horizontal)

                // ── Save button ────────────────────────────────────────────
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
            await activityVM.saveActivity(userId: userId, babyId: baby.id, type: type)
            isSaving = false
            onSaved?()
        }
    }
}

// MARK: - SideButton

private struct SideButton: View {
    let side: Activity.BreastSide
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: sideIcon)
                    .font(.title3)
                Text(side.displayName)
                    .font(.caption.bold())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? color : color.opacity(0.08))
            .foregroundStyle(isSelected ? .white : color)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? color : .clear, lineWidth: 2)
            )
        }
        .animation(.spring(duration: 0.25), value: isSelected)
    }

    private var sideIcon: String {
        switch side {
        case .left:  "arrow.left"
        case .right: "arrow.right"
        case .both:  "arrow.left.arrow.right"
        }
    }
}

#Preview {
    FeedingRecordView(type: .feedingBreast)
        .environment(ActivityViewModel())
        .environment(BabyViewModel())
        .environment(AuthViewModel())
}

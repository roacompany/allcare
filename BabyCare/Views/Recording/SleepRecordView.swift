import SwiftUI

// MARK: - SleepRecordView
// Sleep recording: large timer + sleep quality + sleep method + note.

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

                // ── Sleep method (잠드는 방법) ───────────────────────────
                VStack(alignment: .leading, spacing: 10) {
                    Label("잠드는 방법", systemImage: "zzz")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)

                    FlowLayout(spacing: 8) {
                        ForEach(Activity.SleepMethodType.allCases, id: \.self) { method in
                            Button {
                                activityVM.sleepMethod = activityVM.sleepMethod == method ? nil : method
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

// MARK: - FlowLayout

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
        }

        return (CGSize(width: maxWidth, height: currentY + lineHeight), positions)
    }
}

#Preview {
    SleepRecordView()
        .environment(ActivityViewModel())
        .environment(BabyViewModel())
        .environment(AuthViewModel())
}

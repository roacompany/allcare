import SwiftUI

// MARK: - DiaperRecordView
// Diaper type selection with one-tap quick save.

struct DiaperRecordView: View {
    @Environment(ActivityViewModel.self) private var activityVM
    @Environment(BabyViewModel.self) private var babyVM
    @Environment(AuthViewModel.self) private var authVM
    @Environment(ProductViewModel.self) private var productVM

    var onSaved: (() -> Void)? = nil

    @State private var selectedDiaperType: Activity.ActivityType = .diaperWet
    @State private var isSaving = false
    @State private var productCandidates: [BabyProduct] = []

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

                // ── Stool details (대변/소변+대변 시에만 표시) ────────────
                if selectedDiaperType == .diaperDirty || selectedDiaperType == .diaperBoth {
                    StoolDetailSection(accentColor: cardColor(for: .diaperDirty))
                        .padding(.horizontal)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

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
        .sheet(isPresented: Binding(
            get: { !productCandidates.isEmpty },
            set: { if !$0 { productCandidates = [] } }
        )) {
            ProductPickerSheet(products: productCandidates) { selected in
                Task {
                    guard let userId = authVM.currentUserId else { return }
                    await productVM.deductFromProduct(selected, userId: userId)
                }
                productCandidates = []
                isSaving = false
                onSaved?()
            }
            .presentationDetents([.medium])
        }
    }

    // MARK: - Actions

    private func quickSave() {
        guard let userId = authVM.currentUserId,
              let baby = babyVM.selectedBaby else { return }
        isSaving = true
        Task {
            await activityVM.saveActivity(
                userId: userId,
                babyId: baby.id,
                type: selectedDiaperType
            )
            guard activityVM.errorMessage == nil else {
                isSaving = false
                return
            }
            if let candidates = await productVM.deductStockForActivity(selectedDiaperType, userId: userId) {
                productCandidates = candidates
            } else {
                isSaving = false
                onSaved?()
            }
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

// MARK: - StoolDetailSection

private struct StoolDetailSection: View {
    @Environment(ActivityViewModel.self) private var activityVM
    let accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // 대변 색상
            VStack(alignment: .leading, spacing: 8) {
                Label("대변 색상", systemImage: "paintpalette.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    ForEach(Activity.StoolColor.allCases, id: \.self) { color in
                        Button {
                            activityVM.stoolColor = activityVM.stoolColor == color ? nil : color
                        } label: {
                            VStack(spacing: 4) {
                                Circle()
                                    .fill(Color(hex: color.colorHex))
                                    .frame(width: 36, height: 36)
                                    .overlay(
                                        Circle()
                                            .stroke(
                                                activityVM.stoolColor == color ? Color.primary : .clear,
                                                lineWidth: 2.5
                                            )
                                            .padding(-2)
                                    )
                                    .overlay {
                                        if activityVM.stoolColor == color {
                                            Image(systemName: "checkmark")
                                                .font(.caption.bold())
                                                .foregroundStyle(color == .white ? .black : .white)
                                        }
                                    }
                                Text(color.displayName)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(.primary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }

                // 의료 주의 경고
                if let color = activityVM.stoolColor, color.needsAttention {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.white)
                        Text(color == .red
                             ? "붉은색 대변은 혈변일 수 있습니다. 소아과 상담을 권장합니다."
                             : "흰색 대변은 담도 이상의 신호일 수 있습니다. 소아과 상담을 권장합니다.")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }

            Divider()

            // 대변 농도
            VStack(alignment: .leading, spacing: 8) {
                Label("대변 농도", systemImage: "water.waves")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    ForEach(Activity.StoolConsistency.allCases, id: \.self) { consistency in
                        Button {
                            activityVM.stoolConsistency = activityVM.stoolConsistency == consistency ? nil : consistency
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: consistency.icon)
                                    .font(.body)
                                Text(consistency.displayName)
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                activityVM.stoolConsistency == consistency
                                    ? accentColor : accentColor.opacity(0.08)
                            )
                            .foregroundStyle(
                                activityVM.stoolConsistency == consistency ? .white : accentColor
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
            }

            Divider()

            // 발진 체크
            HStack {
                Label("발진 여부", systemImage: "bandage.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { activityVM.hasRash },
                    set: { activityVM.hasRash = $0 }
                ))
                .labelsHidden()
                .tint(.red)
            }

            if activityVM.hasRash {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(.orange)
                    Text("발진이 지속되면 소아과 상담을 권장합니다.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                .transition(.opacity)
            }
        }
        .padding()
        .background(accentColor.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .animation(.spring(duration: 0.3), value: activityVM.stoolColor)
        .animation(.spring(duration: 0.3), value: activityVM.hasRash)
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

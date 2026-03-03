import SwiftUI

// MARK: - FeedingRecordView
// Handles both breast and bottle (and solid / snack) feeding records.

struct FeedingRecordView: View {
    @Environment(ActivityViewModel.self) private var activityVM
    @Environment(BabyViewModel.self) private var babyVM
    @Environment(AuthViewModel.self) private var authVM
    @Environment(ProductViewModel.self) private var productVM

    let type: Activity.ActivityType
    var onSaved: (() -> Void)? = nil

    @State private var isSaving = false
    @State private var productCandidates: [BabyProduct] = []

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

                // ── Solid food details (이유식) ─────────────────────────
                if type == .feedingSolid {
                    SolidFoodSection(accentColor: accentColor)
                        .padding(.horizontal)
                }

                // ── Snack details (간식) ─────────────────────────────────
                if type == .feedingSnack {
                    SnackSection(accentColor: accentColor)
                        .padding(.horizontal)
                }

                // ── Amount input (bottle only) ───────────────────────────
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

    private func save() {
        guard let userId = authVM.currentUserId,
              let baby = babyVM.selectedBaby else { return }
        isSaving = true
        Task {
            await activityVM.saveActivity(userId: userId, babyId: baby.id, type: type)
            guard activityVM.errorMessage == nil else {
                isSaving = false
                return
            }
            if let candidates = await productVM.deductStockForActivity(type, userId: userId) {
                productCandidates = candidates
            } else {
                isSaving = false
                onSaved?()
            }
        }
    }
}

// MARK: - SolidFoodSection (이유식)

private struct SolidFoodSection: View {
    @Environment(ActivityViewModel.self) private var activityVM
    let accentColor: Color

    private let ingredientChips = ["쌀미음", "감자", "고구마", "당근", "브로콜리", "소고기", "닭고기", "바나나", "사과", "두부"]
    private let amountChips = ["1숟가락", "3숟가락", "5숟가락", "30g", "50g", "80g", "100g"]

    var body: some View {
        @Bindable var vm = activityVM

        VStack(alignment: .leading, spacing: 16) {
            // 음식명
            VStack(alignment: .leading, spacing: 8) {
                Label("음식 이름", systemImage: "fork.knife")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)

                TextField("음식 이름 입력", text: $vm.foodName)
                    .padding(14)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                Text("자주 쓰는 재료")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                FlowLayout(spacing: 8) {
                    ForEach(ingredientChips, id: \.self) { chip in
                        Button(chip) {
                            if activityVM.foodName.isEmpty {
                                activityVM.foodName = chip
                            } else if !activityVM.foodName.contains(chip) {
                                activityVM.foodName += ", \(chip)"
                            }
                        }
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            activityVM.foodName.contains(chip)
                                ? accentColor : accentColor.opacity(0.1)
                        )
                        .foregroundStyle(
                            activityVM.foodName.contains(chip) ? .white : accentColor
                        )
                        .clipShape(Capsule())
                    }
                }
            }

            Divider()

            // 섭취량
            VStack(alignment: .leading, spacing: 8) {
                Label("섭취량", systemImage: "chart.bar.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)

                FlowLayout(spacing: 8) {
                    ForEach(amountChips, id: \.self) { chip in
                        Button(chip) {
                            activityVM.foodAmount = activityVM.foodAmount == chip ? "" : chip
                        }
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            activityVM.foodAmount == chip
                                ? accentColor : accentColor.opacity(0.1)
                        )
                        .foregroundStyle(
                            activityVM.foodAmount == chip ? .white : accentColor
                        )
                        .clipShape(Capsule())
                    }
                }
            }

            Divider()

            // 반응
            VStack(alignment: .leading, spacing: 8) {
                Label("아기 반응", systemImage: "face.smiling.inverse")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    ForEach(Activity.FoodReaction.allCases, id: \.self) { reaction in
                        Button {
                            activityVM.foodReaction = activityVM.foodReaction == reaction ? nil : reaction
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: reaction.icon)
                                    .font(.body)
                                Text(reaction.displayName)
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                activityVM.foodReaction == reaction
                                    ? (reaction == .allergy ? Color.red : accentColor)
                                    : (reaction == .allergy ? Color.red.opacity(0.08) : accentColor.opacity(0.08))
                            )
                            .foregroundStyle(
                                activityVM.foodReaction == reaction
                                    ? .white
                                    : (reaction == .allergy ? .red : accentColor)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }

                // 알레르기 경고 배너
                if activityVM.foodReaction == .allergy {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.white)
                        Text("알레르기 반응이 의심됩니다. 소아과 상담을 권장합니다.")
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
        }
        .padding()
        .background(accentColor.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .animation(.spring(duration: 0.3), value: activityVM.foodReaction)
    }
}

// MARK: - SnackSection (간식)

private struct SnackSection: View {
    @Environment(ActivityViewModel.self) private var activityVM
    let accentColor: Color

    private let snackChips = ["과일", "떡뻥", "퓨레", "요거트", "치즈", "빵"]
    private let amountChips = ["조금", "반개", "1개", "한줌"]

    var body: some View {
        @Bindable var vm = activityVM

        VStack(alignment: .leading, spacing: 16) {
            // 음식명
            VStack(alignment: .leading, spacing: 8) {
                Label("간식 이름", systemImage: "carrot.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)

                TextField("간식 이름 입력", text: $vm.foodName)
                    .padding(14)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                Text("자주 쓰는 간식")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                FlowLayout(spacing: 8) {
                    ForEach(snackChips, id: \.self) { chip in
                        Button(chip) {
                            activityVM.foodName = activityVM.foodName == chip ? "" : chip
                        }
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            activityVM.foodName == chip
                                ? accentColor : accentColor.opacity(0.1)
                        )
                        .foregroundStyle(
                            activityVM.foodName == chip ? .white : accentColor
                        )
                        .clipShape(Capsule())
                    }
                }
            }

            Divider()

            // 섭취량
            VStack(alignment: .leading, spacing: 8) {
                Label("섭취량", systemImage: "chart.bar.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    ForEach(amountChips, id: \.self) { chip in
                        Button(chip) {
                            activityVM.foodAmount = activityVM.foodAmount == chip ? "" : chip
                        }
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            activityVM.foodAmount == chip
                                ? accentColor : accentColor.opacity(0.1)
                        )
                        .foregroundStyle(
                            activityVM.foodAmount == chip ? .white : accentColor
                        )
                        .clipShape(Capsule())
                    }
                }
            }
        }
        .padding()
        .background(accentColor.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - FlowLayout (칩 정렬용)

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
        .environment(ProductViewModel())
}

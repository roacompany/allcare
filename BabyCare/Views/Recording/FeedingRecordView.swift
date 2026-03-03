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

                // ── 이유식 상세 입력 ──────────────────────────────────────
                if type == .feedingSolid {
                    SolidFoodSection(accentColor: accentColor)
                }

                // ── 간식 상세 입력 ───────────────────────────────────────
                if type == .feedingSnack {
                    SnackSection(accentColor: accentColor)
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

// MARK: - SolidFoodSection (이유식 상세)

private struct SolidFoodSection: View {
    @Environment(ActivityViewModel.self) private var activityVM
    let accentColor: Color

    private let commonFoods = ["쌀미음", "감자", "고구마", "당근", "브로콜리", "소고기", "닭고기", "바나나", "사과", "두부"]
    private let amountPresets = ["1숟가락", "3숟가락", "5숟가락", "30g", "50g", "80g", "100g"]

    var body: some View {
        VStack(spacing: 16) {
            // ── 이유식 단계 ───────────────────────────────────────
            VStack(alignment: .leading, spacing: 10) {
                Label("이유식 단계", systemImage: "chart.bar.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    ForEach(Activity.SolidStage.allCases, id: \.self) { stage in
                        Button {
                            withAnimation(.spring(duration: 0.25)) {
                                activityVM.solidStage = stage
                            }
                        } label: {
                            VStack(spacing: 3) {
                                Text(stage.displayName)
                                    .font(.system(size: 14, weight: .semibold))
                                Text(stage.ageHint)
                                    .font(.system(size: 10))
                                    .foregroundStyle(activityVM.solidStage == stage ? .white.opacity(0.8) : .secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(activityVM.solidStage == stage ? accentColor : accentColor.opacity(0.08))
                            .foregroundStyle(activityVM.solidStage == stage ? .white : accentColor)
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

            // ── 음식 이름 ────────────────────────────────────────
            VStack(alignment: .leading, spacing: 10) {
                Label("음식 이름", systemImage: "fork.knife")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)

                TextField("예: 소고기 브로콜리죽", text: Binding(
                    get: { activityVM.foodName },
                    set: { activityVM.foodName = $0 }
                ))
                .padding(14)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .font(.body)

                Text("자주 사용하는 재료")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(commonFoods, id: \.self) { food in
                            Button(food) {
                                if activityVM.foodName.isEmpty {
                                    activityVM.foodName = food
                                } else {
                                    activityVM.foodName += " \(food)"
                                }
                            }
                            .font(.system(size: 13, weight: .medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(accentColor.opacity(0.1))
                            .foregroundStyle(accentColor)
                            .clipShape(Capsule())
                        }
                    }
                }
            }
            .padding()
            .background(accentColor.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)

            // ── 섭취량 ──────────────────────────────────────────
            VStack(alignment: .leading, spacing: 10) {
                Label("섭취량", systemImage: "scalemass.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)

                TextField("예: 50g 또는 3숟가락", text: Binding(
                    get: { activityVM.foodAmount },
                    set: { activityVM.foodAmount = $0 }
                ))
                .padding(14)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .font(.body)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(amountPresets, id: \.self) { preset in
                            Button(preset) {
                                activityVM.foodAmount = preset
                            }
                            .font(.system(size: 13, weight: .medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                activityVM.foodAmount == preset
                                    ? accentColor : accentColor.opacity(0.1)
                            )
                            .foregroundStyle(
                                activityVM.foodAmount == preset ? .white : accentColor
                            )
                            .clipShape(Capsule())
                        }
                    }
                }
            }
            .padding()
            .background(accentColor.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)

            // ── 알레르기 반응 ────────────────────────────────────
            HStack(spacing: 12) {
                Image(systemName: activityVM.allergyReaction ? "exclamationmark.triangle.fill" : "checkmark.shield.fill")
                    .font(.title3)
                    .foregroundStyle(activityVM.allergyReaction ? .red : .green)

                VStack(alignment: .leading, spacing: 2) {
                    Text("알레르기 반응")
                        .font(.subheadline.bold())
                    Text(activityVM.allergyReaction ? "반응이 있었어요" : "반응 없음")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { activityVM.allergyReaction },
                    set: { activityVM.allergyReaction = $0 }
                ))
                .labelsHidden()
                .tint(.red)
            }
            .padding()
            .background(
                activityVM.allergyReaction
                    ? Color.red.opacity(0.08)
                    : Color.green.opacity(0.06)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)
            .animation(.easeInOut(duration: 0.2), value: activityVM.allergyReaction)
        }
    }
}

// MARK: - SnackSection (간식 상세)

private struct SnackSection: View {
    @Environment(ActivityViewModel.self) private var activityVM
    let accentColor: Color

    private let commonSnacks = ["과일", "떡뻥", "퓨레", "요거트", "치즈", "빵", "비스킷", "고구마"]
    private let amountPresets = ["조금", "반개", "1개", "한줌"]

    var body: some View {
        VStack(spacing: 16) {
            // ── 간식 이름 ────────────────────────────────────────
            VStack(alignment: .leading, spacing: 10) {
                Label("간식 이름", systemImage: "carrot.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)

                TextField("예: 사과 퓨레", text: Binding(
                    get: { activityVM.foodName },
                    set: { activityVM.foodName = $0 }
                ))
                .padding(14)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .font(.body)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(commonSnacks, id: \.self) { snack in
                            Button(snack) {
                                activityVM.foodName = snack
                            }
                            .font(.system(size: 13, weight: .medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(
                                activityVM.foodName == snack
                                    ? accentColor : accentColor.opacity(0.1)
                            )
                            .foregroundStyle(
                                activityVM.foodName == snack ? .white : accentColor
                            )
                            .clipShape(Capsule())
                        }
                    }
                }
            }
            .padding()
            .background(accentColor.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)

            // ── 섭취량 ──────────────────────────────────────────
            VStack(alignment: .leading, spacing: 10) {
                Label("섭취량", systemImage: "scalemass.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    ForEach(amountPresets, id: \.self) { preset in
                        Button(preset) {
                            activityVM.foodAmount = preset
                        }
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            activityVM.foodAmount == preset
                                ? accentColor : accentColor.opacity(0.1)
                        )
                        .foregroundStyle(
                            activityVM.foodAmount == preset ? .white : accentColor
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
    }
}

#Preview {
    FeedingRecordView(type: .feedingBreast)
        .environment(ActivityViewModel())
        .environment(BabyViewModel())
        .environment(AuthViewModel())
        .environment(ProductViewModel())
}

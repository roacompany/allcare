import SwiftUI

// MARK: - HealthRecordView
// Handles temperature input, medication input, and bath timer in one view
// with a segmented-style type picker.

struct HealthRecordView: View {
    @Environment(ActivityViewModel.self) private var activityVM
    @Environment(BabyViewModel.self) private var babyVM
    @Environment(AuthViewModel.self) private var authVM
    @Environment(ProductViewModel.self) private var productVM

    var onSaved: (() -> Void)? = nil

    @State private var selectedHealthType: HealthType = .temperature
    @State private var isSaving = false
    @State private var productCandidates: [BabyProduct] = []

    // MARK: - Health sub-types
    enum HealthType: String, CaseIterable, Identifiable {
        case temperature = "체온"
        case medication  = "투약"
        case bath        = "목욕"
        var id: String { rawValue }

        var icon: String {
            switch self {
            case .temperature: "thermometer.medium"
            case .medication:  "pills.fill"
            case .bath:        "bathtub.fill"
            }
        }

        var activityType: Activity.ActivityType {
            switch self {
            case .temperature: .temperature
            case .medication:  .medication
            case .bath:        .bath
            }
        }

        var accentColor: Color {
            switch self {
            case .temperature: Color(hex: "F4845F")  // warm coral
            case .medication:  Color(hex: "A078D4")  // soft purple
            case .bath:        Color(hex: "5CB8E4")  // sky blue
            }
        }
    }

    private var accent: Color { selectedHealthType.accentColor }

    var body: some View {
        @Bindable var vm = activityVM

        ScrollView {
            VStack(spacing: 20) {

                // ── Sub-type picker ────────────────────────────────────────
                HStack(spacing: 0) {
                    ForEach(HealthType.allCases) { hType in
                        Button {
                            if activityVM.isTimerRunning {
                                _ = activityVM.stopTimer()
                            }
                            withAnimation(.spring(duration: 0.3)) {
                                selectedHealthType = hType
                            }
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: hType.icon)
                                    .font(.body)
                                Text(hType.rawValue)
                                    .font(.caption.bold())
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                selectedHealthType == hType
                                    ? hType.accentColor
                                    : hType.accentColor.opacity(0.08)
                            )
                            .foregroundStyle(
                                selectedHealthType == hType ? .white : hType.accentColor
                            )
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 0))

                        if hType != HealthType.allCases.last {
                            Divider()
                                .frame(height: 48)
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(accent.opacity(0.2), lineWidth: 1.5)
                )
                .padding(.horizontal)
                .animation(.spring(duration: 0.3), value: selectedHealthType)

                // ── Time adjustment ───────────────────────────────────────
                TimeAdjustmentSection(
                    accentColor: accent,
                    showEndTime: selectedHealthType == .bath
                )

                // ── Content area ───────────────────────────────────────────
                Group {
                    switch selectedHealthType {
                    case .temperature:
                        TemperatureSection(accentColor: accent)
                    case .medication:
                        MedicationSection(accentColor: accent)
                    case .bath:
                        BathSection(accentColor: accent)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))

                // ── Note ───────────────────────────────────────────────────
                NoteField(note: $vm.note, accentColor: accent)
                    .padding(.horizontal)

                // ── Save ───────────────────────────────────────────────────
                SaveButton(isSaving: isSaving, color: accent, action: save)
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
            await activityVM.saveActivity(
                userId: userId,
                babyId: baby.id,
                type: selectedHealthType.activityType
            )
            guard activityVM.errorMessage == nil else {
                isSaving = false
                return
            }
            if let candidates = await productVM.deductStockForActivity(selectedHealthType.activityType, userId: userId) {
                productCandidates = candidates
            } else {
                isSaving = false
                onSaved?()
            }
        }
    }
}

// MARK: - TemperatureSection

private struct TemperatureSection: View {
    @Environment(ActivityViewModel.self) private var activityVM
    let accentColor: Color

    // Fever thresholds
    private var temperatureDouble: Double { Double(activityVM.temperatureInput) ?? 0 }
    private var feverStatus: (String, Color)? {
        guard temperatureDouble > 0 else { return nil }
        if temperatureDouble >= 38.5 { return ("고열", .red) }
        if temperatureDouble >= 37.5 { return ("미열", Color(hex: "F4845F")) }
        return ("정상", .green)
    }

    var body: some View {
        @Bindable var vm = activityVM

        VStack(alignment: .leading, spacing: 12) {
            Label("체온 입력", systemImage: "thermometer.medium")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                TextField("36.5", text: $vm.temperatureInput)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                Text("°C")
                    .font(.title.bold())
                    .foregroundStyle(.secondary)
            }

            if let (label, color) = feverStatus {
                HStack {
                    Spacer()
                    Label(label, systemImage: "circle.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(color)
                }
                .transition(.opacity)
            }

            // Quick-entry buttons
            HStack(spacing: 8) {
                ForEach(["36.5", "37.0", "37.5", "38.0", "38.5"], id: \.self) { temp in
                    Button(temp) {
                        activityVM.temperatureInput = temp
                    }
                    .font(.system(size: 13, weight: .medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        activityVM.temperatureInput == temp
                            ? accentColor
                            : accentColor.opacity(0.1)
                    )
                    .foregroundStyle(
                        activityVM.temperatureInput == temp ? .white : accentColor
                    )
                    .clipShape(Capsule())
                }
            }
        }
        .padding()
        .background(accentColor.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
        .animation(.easeInOut(duration: 0.2), value: activityVM.temperatureInput)
    }
}

// MARK: - MedicationSection

private struct MedicationSection: View {
    @Environment(ActivityViewModel.self) private var activityVM
    let accentColor: Color

    private let suggestions = ["타이레놀", "이부프로펜", "콧물약", "소화제", "영양제"]
    private let dosageChips = ["2.5ml", "5ml", "10ml", "반정", "1정"]

    var body: some View {
        @Bindable var vm = activityVM

        VStack(alignment: .leading, spacing: 12) {
            Label("투약 정보", systemImage: "pills.fill")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)

            TextField("약 이름 입력", text: $vm.medicationName)
                .padding(14)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .font(.body)

            // Suggestion chips
            Text("자주 사용하는 약")
                .font(.caption)
                .foregroundStyle(.tertiary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(suggestions, id: \.self) { name in
                        Button(name) {
                            activityVM.medicationName = name
                        }
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            activityVM.medicationName == name
                                ? accentColor
                                : accentColor.opacity(0.1)
                        )
                        .foregroundStyle(
                            activityVM.medicationName == name ? .white : accentColor
                        )
                        .clipShape(Capsule())
                    }
                }
            }

            Divider()

            // 용량 입력
            Label("용량", systemImage: "drop.fill")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)

            TextField("용량 입력 (예: 5ml)", text: $vm.medicationDosage)
                .padding(14)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            Text("자주 사용하는 용량")
                .font(.caption)
                .foregroundStyle(.tertiary)

            HStack(spacing: 8) {
                ForEach(dosageChips, id: \.self) { dosage in
                    Button(dosage) {
                        activityVM.medicationDosage = activityVM.medicationDosage == dosage ? "" : dosage
                    }
                    .font(.system(size: 13, weight: .medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        activityVM.medicationDosage == dosage
                            ? accentColor
                            : accentColor.opacity(0.1)
                    )
                    .foregroundStyle(
                        activityVM.medicationDosage == dosage ? .white : accentColor
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

// MARK: - BathSection

private struct BathSection: View {
    let accentColor: Color

    var body: some View {
        VStack(spacing: 8) {
            TimerView(type: .bath, accentColor: accentColor)
                .padding(.vertical, 4)

            Text("목욕 시작 시 타이머를 켜세요")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(accentColor.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }
}

#Preview {
    HealthRecordView()
        .environment(ActivityViewModel())
        .environment(BabyViewModel())
        .environment(AuthViewModel())
}

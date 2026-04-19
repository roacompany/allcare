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
            case .temperature: AppColors.coralColor
            case .medication:  AppColors.softPurpleColor
            case .bath:        AppColors.skyBlueColor
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
        guard let currentUserId = authVM.currentUserId,
              let baby = babyVM.selectedBaby else { return }
        let dataUserId = babyVM.dataUserId(currentUserId: currentUserId) ?? currentUserId
        isSaving = true
        Task {
            await activityVM.saveActivity(
                userId: dataUserId,
                currentUserId: currentUserId,
                babyId: baby.id,
                type: selectedHealthType.activityType
            )
            guard activityVM.errorMessage == nil else {
                isSaving = false
                return
            }
            if let candidates = await productVM.deductStockForActivity(selectedHealthType.activityType, userId: currentUserId) {
                productCandidates = candidates
            } else {
                isSaving = false
                onSaved?()
            }
        }
    }
}

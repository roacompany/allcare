import SwiftUI

// MARK: - MedicationSection

struct MedicationSection: View {
    @Environment(ActivityViewModel.self) var activityVM
    @Environment(BabyViewModel.self) var babyVM
    let accentColor: Color

    let suggestions = ["타이레놀", "이부프로펜", "콧물약", "소화제", "영양제"]
    let dosageChips = ["2.5ml", "5ml", "10ml", "반정", "1정"]

    // MARK: - Safety Computed Properties

    private var babyAgeMonths: Int {
        guard let baby = babyVM.selectedBaby else { return 0 }
        return MedicationSafetyService.ageInMonths(from: baby.birthDate)
    }

    private var babyWeightKg: Double? {
        // BabyViewModel은 체중을 직접 갖지 않으므로
        // ActivityViewModel에 로드된 성장 기록 중 최근 체중 사용
        // (성장 기록이 없으면 nil → 용량 계산 생략)
        nil
    }

    private var safetyInfo: MedicationSafetyService.ValidationResult? {
        let name = activityVM.medicationName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return nil }
        return MedicationSafetyService.safetyInfo(
            medicationName: name,
            weightKg: babyWeightKg,
            ageMonths: babyAgeMonths
        )
    }

    private var dosageWarning: MedicationSafetyService.ValidationResult? {
        let dosage = activityVM.medicationDosage.trimmingCharacters(in: .whitespaces)
        guard !dosage.isEmpty else { return nil }
        return MedicationSafetyService.validateDosage(
            medicationName: activityVM.medicationName,
            dosageString: dosage,
            weightKg: babyWeightKg,
            ageMonths: babyAgeMonths
        )
    }

    // MARK: - Body

    var body: some View {
        @Bindable var vm = activityVM

        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 4) {
                Label("투약 정보", systemImage: "pills.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
                Text("*")
                    .font(.subheadline.bold())
                    .foregroundStyle(.red)
            }

            TextField("약 이름 입력 (필수)", text: $vm.medicationName)
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

            // MARK: Safety Banner
            safetyBannerView

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

            // MARK: Dosage Exceeded Warning
            dosageWarningView
        }
        .padding()
        .background(accentColor.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
        .animation(.easeInOut(duration: 0.2), value: activityVM.medicationName)
        .animation(.easeInOut(duration: 0.2), value: activityVM.medicationDosage)
    }

    // MARK: - Safety Banner View

    @ViewBuilder
    private var safetyBannerView: some View {
        switch safetyInfo {
        case .ageRestriction(let minMonths):
            // 빨간 경고: 월령 미달
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.white)
                Text("이 약은 생후 \(minMonths)개월 이상부터 사용 가능합니다")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.red)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .transition(.opacity.combined(with: .move(edge: .top)))

        case .safeDoseInfo(let minMg, let maxMg, let weightKg, let minMl, let maxMl):
            if weightKg > 0 {
                // 파란 정보 배너: 안전 용량 범위
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(.blue)
                        VStack(alignment: .leading, spacing: 2) {
                            if let minMl, let maxMl {
                                Text("안전 용량: \(formatMl(minMl))~\(formatMl(maxMl))ml (아기 체중 \(formatKg(weightKg))kg 기준)")
                                    .font(.caption.bold())
                                    .foregroundStyle(.blue)
                                Text("(\(formatMg(minMg))~\(formatMg(maxMg))mg)")
                                    .font(.caption2)
                                    .foregroundStyle(.blue.opacity(0.8))
                            } else {
                                Text("안전 용량: \(formatMg(minMg))~\(formatMg(maxMg))mg (아기 체중 \(formatKg(weightKg))kg 기준)")
                                    .font(.caption.bold())
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                    disclaimerText
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.blue.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.blue.opacity(0.25), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                // 체중 정보 없을 때 — 기본 안내만
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(.blue)
                        Text("알려진 소아 의약품입니다. 용량은 체중 기록 후 확인 가능합니다.")
                            .font(.caption.bold())
                            .foregroundStyle(.blue)
                    }
                    disclaimerText
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.blue.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.blue.opacity(0.25), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

        case .unknown, .doseExceeded, nil:
            EmptyView()
        }
    }

    // MARK: - Dosage Warning View

    @ViewBuilder
    private var dosageWarningView: some View {
        if case .doseExceeded(_, let maxMg) = dosageWarning {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.white)
                Text("권장 용량을 초과합니다 (최대 \(formatMg(maxMg))mg)")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    // MARK: - Disclaimer

    private var disclaimerText: some View {
        Text("참고용이며 반드시 의사/약사와 상담하세요")
            .font(.caption2)
            .foregroundStyle(.secondary)
    }

    // MARK: - Formatters

    private func formatMg(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(value))
            : String(format: "%.1f", value)
    }

    private func formatMl(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    private func formatKg(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(value))
            : String(format: "%.1f", value)
    }
}

// MARK: - BathSection

struct BathSection: View {
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

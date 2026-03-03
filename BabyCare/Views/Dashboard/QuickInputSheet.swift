import SwiftUI

struct QuickInputSheet: View {
    let type: Activity.ActivityType
    let onSave: (Activity) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(BabyViewModel.self) private var babyVM

    // 체온
    @State private var temperature = "36.5"

    // 투약
    @State private var medicationName = ""
    @State private var medicationDosage = ""

    // 분유
    @State private var amount = ""

    private var canSave: Bool {
        switch type {
        case .temperature:
            return Double(temperature) != nil
        case .medication:
            return !medicationName.trimmingCharacters(in: .whitespaces).isEmpty
        case .feedingBottle:
            return Double(amount) != nil && (Double(amount) ?? 0) > 0
        default:
            return true
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 타입 헤더
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color(type.color).opacity(0.2))
                            .frame(width: 48, height: 48)
                        Image(systemName: type.icon)
                            .font(.title3)
                            .foregroundStyle(Color(type.color))
                    }
                    Text(type.displayName)
                        .font(.title3.weight(.semibold))
                    Spacer()
                }
                .padding()

                Divider()

                // 입력 필드
                Form {
                    switch type {
                    case .temperature:
                        temperatureInput
                    case .medication:
                        medicationInput
                    case .feedingBottle:
                        bottleInput
                    default:
                        EmptyView()
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        save()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSave)
                }
            }
        }
    }

    // MARK: - Temperature Input

    private var temperatureInput: some View {
        Section {
            HStack {
                Text("체온")
                Spacer()
                TextField("36.5", text: $temperature)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                Text("°C")
                    .foregroundStyle(.secondary)
            }

            if let temp = Double(temperature) {
                HStack {
                    Text("상태")
                    Spacer()
                    Text(temperatureStatus(temp))
                        .foregroundStyle(temperatureStatusColor(temp))
                        .fontWeight(.medium)
                }
            }
        } footer: {
            Text("정상 범위: 36.0~37.5°C / 37.5°C 이상 발열 / 38.0°C 이상 고열")
        }
    }

    // MARK: - Medication Input

    private var medicationInput: some View {
        Group {
            Section("약 정보") {
                TextField("약 이름", text: $medicationName)
                TextField("용량 (선택)", text: $medicationDosage)
            }

            if !RecentMedications.list.isEmpty {
                Section("최근 투약") {
                    ForEach(RecentMedications.list, id: \.self) { name in
                        Button {
                            medicationName = name
                        } label: {
                            HStack {
                                Image(systemName: "clock")
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                                Text(name)
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Bottle Input

    private var bottleInput: some View {
        Section {
            HStack {
                Text("수유량")
                Spacer()
                TextField("0", text: $amount)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                Text("ml")
                    .foregroundStyle(.secondary)
            }
        } footer: {
            Text("일반적인 1회 수유량: 신생아 60~90ml, 3개월 120~150ml, 6개월 180~240ml")
        }
    }

    // MARK: - Save

    private func save() {
        guard let babyId = babyVM.selectedBaby?.id else { return }

        var activity = Activity(babyId: babyId, type: type)

        switch type {
        case .temperature:
            activity.temperature = Double(temperature)
        case .medication:
            activity.medicationName = medicationName.trimmingCharacters(in: .whitespaces)
            activity.medicationDosage = medicationDosage.isEmpty ? nil : medicationDosage
            RecentMedications.add(activity.medicationName ?? "")
        case .feedingBottle:
            activity.amount = Double(amount)
        default:
            break
        }

        onSave(activity)
    }

    // MARK: - Helpers

    private func temperatureStatus(_ temp: Double) -> String {
        if temp < 35.0 { return "저체온" }
        if temp <= 37.5 { return "정상" }
        if temp <= 38.0 { return "미열" }
        if temp <= 39.0 { return "발열" }
        return "고열"
    }

    private func temperatureStatusColor(_ temp: Double) -> Color {
        if temp < 35.0 { return .blue }
        if temp <= 37.5 { return Color(hex: "4CAF50") }
        if temp <= 38.0 { return .orange }
        return .red
    }
}

// MARK: - Recent Medications (UserDefaults)

enum RecentMedications {
    private static let key = "recentMedications"
    private static let maxCount = 5

    static var list: [String] {
        UserDefaults.standard.stringArray(forKey: key) ?? []
    }

    static func add(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var meds = list.filter { $0 != trimmed }
        meds.insert(trimmed, at: 0)
        if meds.count > maxCount {
            meds = Array(meds.prefix(maxCount))
        }
        UserDefaults.standard.set(meds, forKey: key)
    }
}

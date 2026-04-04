import SwiftUI

// MARK: - Activity Edit Sheet

struct ActivityEditSheet: View {
    @Environment(\.dismiss) private var dismiss

    let activity: Activity
    let onSave: (Activity) -> Void

    @State private var editedStartTime: Date
    @State private var editedEndTime: Date?
    @State private var editedAmount: String
    @State private var editedTemperature: String
    @State private var editedNote: String
    @State private var editedFoodName: String
    @State private var editedMedicationName: String
    @State private var editedMedicationDosage: String

    init(activity: Activity, onSave: @escaping (Activity) -> Void) {
        self.activity = activity
        self.onSave = onSave
        _editedStartTime = State(initialValue: activity.startTime)
        _editedEndTime = State(initialValue: activity.endTime)
        _editedAmount = State(initialValue: activity.amount.map { String(Int($0)) } ?? "")
        _editedTemperature = State(initialValue: activity.temperature.map { String($0) } ?? "")
        _editedNote = State(initialValue: activity.note ?? "")
        _editedFoodName = State(initialValue: activity.foodName ?? "")
        _editedMedicationName = State(initialValue: activity.medicationName ?? "")
        _editedMedicationDosage = State(initialValue: activity.medicationDosage ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                // 활동 타입 헤더
                Section {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(Color(activity.type.color).opacity(0.18))
                                .frame(width: 36, height: 36)
                            Image(systemName: activity.type.icon)
                                .font(.system(size: 16))
                                .foregroundStyle(Color(activity.type.color))
                        }
                        Text(activity.type.displayName)
                            .font(.headline)
                    }
                }

                // 시작 시간
                Section("시작 시간") {
                    DatePicker(
                        "시작",
                        selection: $editedStartTime,
                        in: ...Date(),
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.graphical)
                }

                // 종료 시간
                if activity.endTime != nil || activity.duration != nil {
                    Section("종료 시간") {
                        DatePicker(
                            "종료",
                            selection: Binding(
                                get: { editedEndTime ?? editedStartTime },
                                set: { editedEndTime = $0 }
                            ),
                            in: editedStartTime...Date(),
                            displayedComponents: [.date, .hourAndMinute]
                        )
                    }
                }

                // 분유 수유량 (ml)
                if activity.type == .feedingBottle {
                    Section("수유량 (ml)") {
                        HStack {
                            TextField("0", text: $editedAmount)
                                .keyboardType(.numberPad)
                                .font(.title2.weight(.semibold))
                            Text("ml")
                                .foregroundStyle(.secondary)
                        }
                        // 빠른 입력
                        HStack(spacing: 8) {
                            ForEach([60, 80, 100, 120, 150, 180], id: \.self) { ml in
                                Button("\(ml)") {
                                    editedAmount = "\(ml)"
                                }
                                .buttonStyle(.bordered)
                                .tint(editedAmount == "\(ml)" ? Color(activity.type.color) : .secondary)
                            }
                        }
                        .font(.caption)
                    }
                }

                // 이유식/간식 음식명
                if activity.type == .feedingSolid || activity.type == .feedingSnack {
                    Section("음식") {
                        TextField("음식 이름", text: $editedFoodName)
                    }
                }

                // 체온
                if activity.type == .temperature {
                    Section("체온 (°C)") {
                        HStack {
                            TextField("36.5", text: $editedTemperature)
                                .keyboardType(.decimalPad)
                                .font(.title2.weight(.semibold))
                            Text("°C")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // 투약
                if activity.type == .medication {
                    Section("투약 정보") {
                        TextField("약 이름", text: $editedMedicationName)
                        TextField("용량 (예: 5ml)", text: $editedMedicationDosage)
                    }
                }

                // 메모 (모든 타입)
                Section("메모") {
                    TextField("메모 입력", text: $editedNote, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("기록 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        var updated = activity

                        // 시간
                        updated.startTime = editedStartTime
                        if let end = editedEndTime {
                            updated.endTime = end
                            updated.duration = end.timeIntervalSince(editedStartTime)
                        } else if activity.duration != nil {
                            let duration = (activity.endTime ?? activity.startTime.addingTimeInterval(activity.duration ?? 0))
                                .timeIntervalSince(activity.startTime)
                            updated.endTime = editedStartTime.addingTimeInterval(duration)
                        }

                        // 수유량
                        if activity.type == .feedingBottle {
                            updated.amount = Double(editedAmount)
                        }

                        // 이유식/간식
                        if activity.type == .feedingSolid || activity.type == .feedingSnack {
                            updated.foodName = editedFoodName.isEmpty ? nil : editedFoodName
                        }

                        // 체온
                        if activity.type == .temperature {
                            updated.temperature = Double(editedTemperature)
                        }

                        // 투약
                        if activity.type == .medication {
                            updated.medicationName = editedMedicationName.isEmpty ? nil : editedMedicationName
                            updated.medicationDosage = editedMedicationDosage.isEmpty ? nil : editedMedicationDosage
                        }

                        // 메모
                        updated.note = editedNote.isEmpty ? nil : editedNote

                        onSave(updated)
                        dismiss()
                    }
                    .bold()
                }
            }
        }
    }
}

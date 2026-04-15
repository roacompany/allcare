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
    // 모유수유
    @State private var editedSide: Activity.BreastSide
    // 수면
    @State private var editedSleepQuality: Activity.SleepQualityType?
    @State private var editedSleepMethod: Activity.SleepMethodType?
    // 기저귀
    @State private var editedStoolColor: Activity.StoolColor?
    @State private var editedStoolConsistency: Activity.StoolConsistency?
    @State private var editedHasRash: Bool

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
        _editedSide = State(initialValue: activity.side ?? .left)
        _editedSleepQuality = State(initialValue: activity.sleepQuality)
        _editedSleepMethod = State(initialValue: activity.sleepMethod)
        _editedStoolColor = State(initialValue: activity.stoolColor)
        _editedStoolConsistency = State(initialValue: activity.stoolConsistency)
        _editedHasRash = State(initialValue: activity.hasRash ?? false)
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

                // 모유수유 좌/우
                if activity.type == .feedingBreast {
                    Section("수유 방향") {
                        Picker("방향", selection: $editedSide) {
                            ForEach(Activity.BreastSide.allCases, id: \.self) { side in
                                Text(side.displayName).tag(side)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }

                // 이유식/간식 음식명
                if activity.type == .feedingSolid || activity.type == .feedingSnack {
                    Section("음식") {
                        TextField("음식 이름", text: $editedFoodName)
                    }
                }

                // 수면 질/방법
                if activity.type == .sleep {
                    Section("수면 정보") {
                        Picker("수면 질", selection: $editedSleepQuality) {
                            Text("선택 안 함").tag(Optional<Activity.SleepQualityType>.none)
                            ForEach(Activity.SleepQualityType.allCases, id: \.self) { quality in
                                Label(quality.displayName, systemImage: quality.icon)
                                    .tag(Optional(quality))
                            }
                        }
                        Picker("잠든 곳", selection: $editedSleepMethod) {
                            Text("선택 안 함").tag(Optional<Activity.SleepMethodType>.none)
                            // 기존 레코드의 deprecated 값(holding/nursing)은 현재 선택 상태로 표시되되
                            // 픽커 목록에서는 감춤. 변경 시 신규 허용값으로 전환.
                            if let current = editedSleepMethod, !Activity.SleepMethodType.selectableCases.contains(current) {
                                Label(current.displayName, systemImage: current.icon)
                                    .tag(Optional(current))
                            }
                            ForEach(Activity.SleepMethodType.selectableCases, id: \.self) { method in
                                Label(method.displayName, systemImage: method.icon)
                                    .tag(Optional(method))
                            }
                        }
                    }
                }

                // 기저귀 대변 색상/농도/발진
                if activity.type == .diaperDirty || activity.type == .diaperBoth {
                    Section("대변 정보") {
                        Picker("색상", selection: $editedStoolColor) {
                            Text("선택 안 함").tag(Optional<Activity.StoolColor>.none)
                            ForEach(Activity.StoolColor.allCases, id: \.self) { color in
                                Text(color.displayName).tag(Optional(color))
                            }
                        }
                        Picker("농도", selection: $editedStoolConsistency) {
                            Text("선택 안 함").tag(Optional<Activity.StoolConsistency>.none)
                            ForEach(Activity.StoolConsistency.allCases, id: \.self) { consistency in
                                Label(consistency.displayName, systemImage: consistency.icon)
                                    .tag(Optional(consistency))
                            }
                        }
                        Toggle("발진 있음", isOn: $editedHasRash)
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

                        // 모유수유 방향
                        if activity.type == .feedingBreast {
                            updated.side = editedSide
                        }

                        // 이유식/간식
                        if activity.type == .feedingSolid || activity.type == .feedingSnack {
                            updated.foodName = editedFoodName.isEmpty ? nil : editedFoodName
                        }

                        // 수면 질/방법
                        if activity.type == .sleep {
                            updated.sleepQuality = editedSleepQuality
                            updated.sleepMethod = editedSleepMethod
                        }

                        // 기저귀 대변 정보
                        if activity.type == .diaperDirty || activity.type == .diaperBoth {
                            updated.stoolColor = editedStoolColor
                            updated.stoolConsistency = editedStoolConsistency
                            updated.hasRash = editedHasRash
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

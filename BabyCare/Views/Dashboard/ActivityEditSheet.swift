import SwiftUI

// MARK: - Activity Edit Sheet

struct ActivityEditSheet: View {
    @Environment(\.dismiss) private var dismiss

    let activity: Activity
    let onSave: (Activity) -> Void

    @State private var editedStartTime: Date
    @State private var editedEndTime: Date?

    init(activity: Activity, onSave: @escaping (Activity) -> Void) {
        self.activity = activity
        self.onSave = onSave
        _editedStartTime = State(initialValue: activity.startTime)
        _editedEndTime = State(initialValue: activity.endTime)
    }

    var body: some View {
        NavigationStack {
            Form {
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

                Section("시작 시간") {
                    DatePicker(
                        "시작",
                        selection: $editedStartTime,
                        in: ...Date(),
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.graphical)
                }

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
            }
            .navigationTitle("시간 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        var updated = activity
                        updated.startTime = editedStartTime
                        if let end = editedEndTime {
                            updated.endTime = end
                            updated.duration = end.timeIntervalSince(editedStartTime)
                        } else if activity.duration != nil {
                            let duration = (activity.endTime ?? activity.startTime.addingTimeInterval(activity.duration ?? 0))
                                .timeIntervalSince(activity.startTime)
                            updated.endTime = editedStartTime.addingTimeInterval(duration)
                        }
                        onSave(updated)
                        dismiss()
                    }
                    .bold()
                }
            }
        }
    }
}

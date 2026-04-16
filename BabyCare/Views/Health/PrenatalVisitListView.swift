import SwiftUI

struct PrenatalVisitListView: View {
    @Environment(PregnancyViewModel.self) private var pregnancyVM
    @Environment(AuthViewModel.self) private var authVM

    @State private var showAddSheet = false

    var body: some View {
        List {
            if pregnancyVM.prenatalVisits.isEmpty {
                ContentUnavailableView(
                    "방문 기록 없음",
                    systemImage: "stethoscope",
                    description: Text("산전 방문 일정을 추가해보세요.")
                )
            } else {
                ForEach(pregnancyVM.prenatalVisits.sorted(by: { $0.scheduledAt < $1.scheduledAt })) { visit in
                    PrenatalVisitRow(visit: visit) {
                        Task {
                            guard let userId = authVM.currentUserId else { return }
                            await toggleVisit(visit, userId: userId)
                        }
                    }
                }
            }
        }
        .navigationTitle("산전 방문")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            PrenatalVisitFormSheet()
                .presentationDetents([.medium, .large])
        }
    }

    private func toggleVisit(_ visit: PrenatalVisit, userId: String) async {
        await pregnancyVM.togglePrenatalVisit(visit, userId: userId)
    }
}

// MARK: - Prenatal Visit Row

private struct PrenatalVisitRow: View {
    let visit: PrenatalVisit
    let onToggle: () -> Void

    private var dDayText: String {
        let days = visit.daysUntilScheduled
        if visit.isCompleted { return "완료" }
        if days == 0 { return "오늘" }
        if days > 0 { return "D-\(days)" }
        return "D+\(-days)"
    }

    private var dDayColor: Color {
        if visit.isCompleted { return .green }
        if visit.isOverdue { return .red }
        if visit.isDueSoon { return .orange }
        return .secondary
    }

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: visit.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(visit.isCompleted ? .green : AppColors.indigoColor.opacity(0.5))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(visit.visitType ?? "산전 진찰")
                    .font(.subheadline.weight(.medium))
                if let hospital = visit.hospitalName {
                    Text(hospital)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(visit.scheduledAt, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(dDayText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(visit.isCompleted ? .white : dDayColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(visit.isCompleted ? Color.green : dDayColor.opacity(0.15))
                .clipShape(Capsule())
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Prenatal Visit Form Sheet

struct PrenatalVisitFormSheet: View {
    @Environment(PregnancyViewModel.self) private var pregnancyVM
    @Environment(AuthViewModel.self) private var authVM
    @Environment(\.dismiss) private var dismiss

    @State private var scheduledAt: Date = Date()
    @State private var hospitalName: String = ""
    @State private var visitType: String = "routine"
    @State private var notes: String = ""
    @State private var reminderEnabled: Bool = true
    @State private var isSaving = false

    private let visitTypes = [
        ("routine", "정기 검진"),
        ("ultrasound", "초음파"),
        ("bloodTest", "혈액검사"),
        ("gtt", "당부하검사"),
        ("other", "기타")
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("방문 일정") {
                    DatePicker("날짜/시간", selection: $scheduledAt)
                        .environment(\.locale, Locale(identifier: "ko_KR"))

                    TextField("병원 이름", text: $hospitalName)

                    Picker("방문 유형", selection: $visitType) {
                        ForEach(visitTypes, id: \.0) { type in
                            Text(type.1).tag(type.0)
                        }
                    }
                }

                Section("메모") {
                    TextField("메모 (선택)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section {
                    Toggle("알림 설정", isOn: $reminderEnabled)
                }
            }
            .navigationTitle("방문 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        Task { await save() }
                    }
                    .disabled(isSaving)
                }
            }
        }
    }

    private func save() async {
        guard let userId = authVM.currentUserId,
              let pid = pregnancyVM.activePregnancy?.id else { return }
        isSaving = true
        defer { isSaving = false }

        let visit = PrenatalVisit(
            pregnancyId: pid,
            scheduledAt: scheduledAt,
            hospitalName: hospitalName.isEmpty ? nil : hospitalName,
            visitType: visitType,
            notes: notes.isEmpty ? nil : notes,
            reminderEnabled: reminderEnabled
        )
        await pregnancyVM.savePrenatalVisit(visit, userId: userId)
        if pregnancyVM.errorMessage == nil {
            dismiss()
        }
    }
}

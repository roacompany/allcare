import SwiftUI

struct VaccinationListView: View {
    @Environment(HealthViewModel.self) private var healthVM
    @Environment(AuthViewModel.self) private var authVM
    @Environment(BabyViewModel.self) private var babyVM

    @State private var selectedVaccination: Vaccination?
    @State private var showCompleteSheet = false
    @State private var showUndoConfirmation = false
    @State private var savedMessage: String?

    var body: some View {
        Group {
            if healthVM.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                vaccinationList
            }
        }
    }

    private var vaccinationList: some View {
        List {
            // 접종 지연
            let overdue = healthVM.overdueVaccinations
            if !overdue.isEmpty {
                Section {
                    ForEach(overdue) { vax in
                        VaccinationRow(vaccination: vax)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedVaccination = vax
                                showCompleteSheet = true
                            }
                    }
                } header: {
                    SectionHeader(title: "접종 지연", color: .red)
                }
            }

            // 접종 예정 (14일 이내)
            let dueSoon = healthVM.vaccinations.filter { $0.isDueSoon && !$0.isOverdue }
            if !dueSoon.isEmpty {
                Section {
                    ForEach(dueSoon) { vax in
                        VaccinationRow(vaccination: vax)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedVaccination = vax
                                showCompleteSheet = true
                            }
                    }
                } header: {
                    SectionHeader(title: "접종 예정 (14일 이내)", color: .orange)
                }
            }

            // 예정 (14일 이후)
            let scheduled = healthVM.vaccinations.filter {
                !$0.isCompleted && !$0.isOverdue && !$0.isDueSoon
            }
            if !scheduled.isEmpty {
                Section {
                    ForEach(scheduled) { vax in
                        VaccinationRow(vaccination: vax)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedVaccination = vax
                                showCompleteSheet = true
                            }
                    }
                } header: {
                    SectionHeader(title: "예정", color: .secondary)
                }
            }

            // 완료
            let completed = healthVM.completedVaccinations
            if !completed.isEmpty {
                Section {
                    ForEach(completed) { vax in
                        VaccinationRow(vaccination: vax)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedVaccination = vax
                                showUndoConfirmation = true
                            }
                    }
                } header: {
                    SectionHeader(title: "완료", color: AppColors.successColor)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("예방접종")
        .navigationBarTitleDisplayMode(.large)
        .overlay(alignment: .bottom) {
            if let msg = savedMessage {
                Text(msg)
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation { savedMessage = nil }
                        }
                    }
            }
        }
        .animation(.easeInOut, value: savedMessage)
        .sheet(isPresented: $showCompleteSheet) {
            if let vax = selectedVaccination {
                MarkVaccinationSheet(vaccination: vax) { administeredDate, hospital, note in
                    guard let currentUserId = authVM.currentUserId else { return }
                    let dataUserId = babyVM.dataUserId(currentUserId: currentUserId) ?? currentUserId
                    var updated = vax
                    updated.hospital = hospital.isEmpty ? nil : hospital
                    updated.note = note.isEmpty ? nil : note
                    Task {
                        await healthVM.markVaccinationComplete(
                            updated,
                            administeredDate: administeredDate,
                            userId: dataUserId
                        )
                        if healthVM.errorMessage == nil {
                            savedMessage = "\(vax.vaccine.displayName) \(vax.doseNumber)차 저장됨"
                        }
                    }
                }
            }
        }
        .confirmationDialog(
            selectedVaccination.map { "\($0.vaccine.displayName) \($0.doseNumber)차" } ?? "",
            isPresented: $showUndoConfirmation,
            titleVisibility: .visible
        ) {
            Button("접종 기록 수정") {
                showCompleteSheet = true
            }
            Button("접종 취소", role: .destructive) {
                guard let vax = selectedVaccination,
                      let currentUserId = authVM.currentUserId else { return }
                let dataUserId = babyVM.dataUserId(currentUserId: currentUserId) ?? currentUserId
                Task {
                    await healthVM.undoVaccinationComplete(vax, userId: dataUserId)
                }
            }
            Button("닫기", role: .cancel) {
                selectedVaccination = nil
            }
        }
        .alert("오류", isPresented: Binding(
            get: { healthVM.errorMessage != nil },
            set: { if !$0 { healthVM.errorMessage = nil } }
        )) {
            Button("확인") { healthVM.errorMessage = nil }
        } message: {
            Text(healthVM.errorMessage ?? "")
        }
    }
}

// MARK: - Vaccination Row

private struct VaccinationRow: View {
    let vaccination: Vaccination

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "syringe.fill")
                .foregroundStyle(statusColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text("\(vaccination.vaccine.displayName) \(vaccination.doseNumber)차")
                    .font(.subheadline.weight(.medium))

                if vaccination.isCompleted, let date = vaccination.administeredDate {
                    Text("접종일: \(DateFormatters.shortDate.string(from: date))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("예정일: \(DateFormatters.shortDate.string(from: vaccination.scheduledDate))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let hospital = vaccination.hospital, !hospital.isEmpty {
                    Text(hospital)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            StatusBadge(text: vaccination.statusText, color: statusColor)
        }
        .padding(.vertical, 4)
    }

    private var statusColor: Color {
        if vaccination.isCompleted { return AppColors.successColor }
        if vaccination.isOverdue { return .red }
        if vaccination.isDueSoon { return .orange }
        return .secondary
    }
}

// MARK: - Status Badge

private struct StatusBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }
}

// MARK: - Section Header

private struct SectionHeader: View {
    let title: String
    let color: Color

    var body: some View {
        Text(title)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(color)
            .textCase(nil)
    }
}

// MARK: - Mark Vaccination Sheet

private struct MarkVaccinationSheet: View {
    let vaccination: Vaccination
    let onSave: (Date, String, String) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var administeredDate = Date()
    @State private var hospital = ""
    @State private var note = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("접종 정보") {
                    HStack {
                        Text("백신")
                        Spacer()
                        Text("\(vaccination.vaccine.displayName) \(vaccination.doseNumber)차")
                            .foregroundStyle(.secondary)
                    }
                    DatePicker(
                        "접종일",
                        selection: $administeredDate,
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    .environment(\.locale, Locale(identifier: "ko_KR"))
                }

                Section("접종 기관") {
                    TextField("병원명 (선택)", text: $hospital)
                }

                Section("메모") {
                    TextField("이상반응, 특이사항 등 (선택)", text: $note, axis: .vertical)
                        .lineLimit(3...5)
                }
            }
            .navigationTitle(vaccination.isCompleted ? "접종 기록 수정" : "접종 완료 기록")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                administeredDate = vaccination.administeredDate ?? Date()
                hospital = vaccination.hospital ?? ""
                note = vaccination.note ?? ""
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        onSave(administeredDate, hospital, note)
                        dismiss()
                    }
                }
            }
        }
    }
}

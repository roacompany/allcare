import SwiftUI

struct HospitalVisitListView: View {
    @Environment(HealthViewModel.self) private var healthVM
    @Environment(AuthViewModel.self) private var authVM
    @Environment(BabyViewModel.self) private var babyVM

    @State private var showAddSheet = false
    @State private var selectedVisit: HospitalVisit?

    var body: some View {
        List {
            // 다음 방문 예정
            if !healthVM.upcomingVisits.isEmpty {
                Section("예정된 방문") {
                    ForEach(healthVM.upcomingVisits) { visit in
                        HospitalVisitRow(visit: visit)
                            .contentShape(Rectangle())
                            .onTapGesture { selectedVisit = visit }
                    }
                }
            }

            // 지난 방문 기록
            if !healthVM.pastVisits.isEmpty {
                Section("지난 기록") {
                    ForEach(healthVM.pastVisits) { visit in
                        HospitalVisitRow(visit: visit)
                            .contentShape(Rectangle())
                            .onTapGesture { selectedVisit = visit }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    deleteVisit(visit)
                                } label: {
                                    Label("삭제", systemImage: "trash")
                                }
                            }
                    }
                }
            }

            if healthVM.hospitalVisits.isEmpty {
                ContentUnavailableView(
                    "병원 기록 없음",
                    systemImage: "building.2",
                    description: Text("병원 방문 기록을 추가해보세요")
                )
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("병원 기록")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            HospitalVisitFormSheet(visit: nil) { visit in
                saveVisit(visit)
            }
        }
        .sheet(item: $selectedVisit) { visit in
            HospitalVisitFormSheet(visit: visit) { updated in
                saveVisit(updated)
            } onDelete: {
                deleteVisit(visit)
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

    private func saveVisit(_ visit: HospitalVisit) {
        guard let userId = authVM.currentUserId else { return }
        Task { await healthVM.saveHospitalVisit(visit, userId: userId) }
    }

    private func deleteVisit(_ visit: HospitalVisit) {
        guard let userId = authVM.currentUserId else { return }
        Task { await healthVM.deleteHospitalVisit(visit, userId: userId) }
    }
}

// MARK: - Visit Row

private struct HospitalVisitRow: View {
    let visit: HospitalVisit

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(hex: visit.visitType.color).opacity(0.2))
                    .frame(width: 40, height: 40)
                Image(systemName: visit.visitType.icon)
                    .font(.body)
                    .foregroundStyle(Color(hex: visit.visitType.color))
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(visit.hospitalName)
                        .font(.subheadline.weight(.medium))
                    Text(visit.visitType.displayName)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color(hex: visit.visitType.color)))
                }

                Text(DateFormatters.dateTime.string(from: visit.visitDate))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let purpose = visit.purpose, !purpose.isEmpty {
                    Text(purpose)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if visit.isUpcoming {
                Text(daysUntilText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.blue)
            }

            if visit.hasNextVisit {
                Image(systemName: "arrow.forward.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 2)
    }

    private var daysUntilText: String {
        let days = Calendar.current.dateComponents([.day], from: Date(), to: visit.visitDate).day ?? 0
        if days == 0 { return "오늘" }
        if days == 1 { return "내일" }
        return "\(days)일 후"
    }
}

// MARK: - Form Sheet

private struct HospitalVisitFormSheet: View {
    let existingVisit: HospitalVisit?
    let onSave: (HospitalVisit) -> Void
    var onDelete: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(BabyViewModel.self) private var babyVM

    @State private var visitType: HospitalVisit.VisitType = .sick
    @State private var hospitalName = ""
    @State private var department = ""
    @State private var doctorName = ""
    @State private var visitDate = Date()
    @State private var purpose = ""
    @State private var diagnosis = ""
    @State private var prescription = ""
    @State private var costText = ""
    @State private var hasNextVisit = false
    @State private var nextVisitDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @State private var note = ""
    @State private var showDeleteAlert = false
    @State private var showRecentHospitals = false
    @State private var addToCalendar = true

    private var isEditing: Bool { existingVisit != nil }
    private var canSave: Bool { !hospitalName.trimmingCharacters(in: .whitespaces).isEmpty }

    init(visit: HospitalVisit?, onSave: @escaping (HospitalVisit) -> Void, onDelete: (() -> Void)? = nil) {
        self.existingVisit = visit
        self.onSave = onSave
        self.onDelete = onDelete
    }

    var body: some View {
        NavigationStack {
            Form {
                // 방문 유형
                Section("방문 유형") {
                    Picker("유형", selection: $visitType) {
                        ForEach(HospitalVisit.VisitType.allCases, id: \.self) { type in
                            Label(type.displayName, systemImage: type.icon).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                }

                // 병원 정보
                Section("병원 정보") {
                    HStack {
                        TextField("병원 이름", text: $hospitalName)
                        if !RecentHospitals.list.isEmpty {
                            Button {
                                showRecentHospitals.toggle()
                            } label: {
                                Image(systemName: "clock.arrow.circlepath")
                                    .foregroundStyle(.blue)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if showRecentHospitals {
                        ForEach(RecentHospitals.list, id: \.self) { name in
                            Button {
                                hospitalName = name
                                showRecentHospitals = false
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

                    TextField("진료과 (선택)", text: $department)
                    TextField("담당의 (선택)", text: $doctorName)
                }

                // 방문 일시
                Section("방문 일시") {
                    DatePicker(
                        "날짜/시간",
                        selection: $visitDate,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .environment(\.locale, Locale(identifier: "ko_KR"))
                }

                // 진료 내용
                Section("진료 내용") {
                    TextField("방문 사유", text: $purpose)
                    TextField("진단명 (선택)", text: $diagnosis)
                    TextField("처방 내용 (선택)", text: $prescription)
                    HStack {
                        Text("비용")
                        Spacer()
                        TextField("0", text: $costText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 120)
                        Text("원")
                            .foregroundStyle(.secondary)
                    }
                }

                // 다음 방문
                Section("다음 방문") {
                    Toggle("다음 방문 예정", isOn: $hasNextVisit)
                    if hasNextVisit {
                        DatePicker(
                            "예정일",
                            selection: $nextVisitDate,
                            in: Date()...,
                            displayedComponents: .date
                        )
                        .environment(\.locale, Locale(identifier: "ko_KR"))
                    }
                }

                // 캘린더
                Section {
                    Toggle("iPhone 캘린더에 추가", isOn: $addToCalendar)
                } footer: {
                    Text("기본 캘린더 앱에 일정이 추가됩니다.")
                }

                // 메모
                Section("메모") {
                    TextField("메모 (선택)", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                }

                // 삭제
                if isEditing, onDelete != nil {
                    Section {
                        Button(role: .destructive) {
                            showDeleteAlert = true
                        } label: {
                            HStack {
                                Spacer()
                                Text("기록 삭제")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "기록 수정" : "병원 방문 기록")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        saveAndDismiss()
                    }
                    .disabled(!canSave)
                }
            }
            .onAppear { loadExisting() }
            .alert("기록 삭제", isPresented: $showDeleteAlert) {
                Button("취소", role: .cancel) {}
                Button("삭제", role: .destructive) {
                    onDelete?()
                    dismiss()
                }
            } message: {
                Text("이 병원 기록을 삭제하시겠습니까?")
            }
        }
    }

    private func loadExisting() {
        guard let v = existingVisit else { return }
        visitType = v.visitType
        hospitalName = v.hospitalName
        department = v.department ?? ""
        doctorName = v.doctorName ?? ""
        visitDate = v.visitDate
        purpose = v.purpose ?? ""
        diagnosis = v.diagnosis ?? ""
        prescription = v.prescription ?? ""
        costText = v.cost.map { String($0) } ?? ""
        hasNextVisit = v.nextVisitDate != nil
        nextVisitDate = v.nextVisitDate ?? Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        note = v.note ?? ""
    }

    private func saveAndDismiss() {
        let visit = buildVisit()
        onSave(visit)

        if addToCalendar {
            let babyName = babyVM.selectedBaby?.name ?? "아기"
            Task {
                _ = await CalendarService.shared.addHospitalVisit(visit, babyName: babyName)
                if visit.nextVisitDate != nil {
                    _ = await CalendarService.shared.addNextVisit(from: visit, babyName: babyName)
                }
            }
        }

        dismiss()
    }

    private func buildVisit() -> HospitalVisit {
        let babyId = babyVM.selectedBaby?.id ?? ""
        return HospitalVisit(
            id: existingVisit?.id ?? UUID().uuidString,
            babyId: babyId,
            visitType: visitType,
            hospitalName: hospitalName.trimmingCharacters(in: .whitespaces),
            department: department.isEmpty ? nil : department,
            doctorName: doctorName.isEmpty ? nil : doctorName,
            visitDate: visitDate,
            purpose: purpose.isEmpty ? nil : purpose,
            diagnosis: diagnosis.isEmpty ? nil : diagnosis,
            prescription: prescription.isEmpty ? nil : prescription,
            cost: Int(costText),
            nextVisitDate: hasNextVisit ? nextVisitDate : nil,
            note: note.isEmpty ? nil : note,
            createdAt: existingVisit?.createdAt ?? Date()
        )
    }
}

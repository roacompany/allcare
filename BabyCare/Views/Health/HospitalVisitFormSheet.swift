import SwiftUI
import MapKit

// MARK: - Form Sheet

struct HospitalVisitFormSheet: View {
    let existingVisit: HospitalVisit?
    let onSave: (HospitalVisit) -> Void
    var onDelete: (() -> Void)?

    @Environment(\.dismiss) var dismiss
    @Environment(BabyViewModel.self) var babyVM
    @Environment(HealthViewModel.self) var healthVM

    @State var visitType: HospitalVisit.VisitType = .sick
    @State var hospitalName = ""
    @State var department = ""
    @State var doctorName = ""
    @State var visitDate = Date()
    @State var purpose = ""
    @State var diagnosis = ""
    @State var prescription = ""
    @State var costText = ""
    @State var hasScheduledDate = false
    @State var scheduledDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @State var hasNextVisit = false
    @State var nextVisitDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @State var note = ""
    @State var showDeleteAlert = false
    @State var showRecentHospitals = false
    @State var addToCalendar = true

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

                    if !healthVM.recentHospitalNames.isEmpty && hospitalName.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(healthVM.recentHospitalNames, id: \.self) { name in
                                    Button(name) { hospitalName = name }
                                        .font(.caption)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color.secondary.opacity(0.1))
                                        .clipShape(Capsule())
                                }
                            }
                            .padding(.vertical, 2)
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
                        Text("₩")
                            .foregroundStyle(.secondary)
                        TextField("0", text: $costText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 120)
                            .onChange(of: costText) { _, newValue in
                                let filtered = newValue.filter(\.isNumber)
                                if filtered != newValue { costText = filtered }
                            }
                    }
                }

                // AI 분석 기준 예약일
                Section {
                    Toggle("이번 진료 예약일", isOn: $hasScheduledDate)
                    if hasScheduledDate {
                        DatePicker(
                            "예약일",
                            selection: $scheduledDate,
                            in: Date()...,
                            displayedComponents: .date
                        )
                        .environment(\.locale, Locale(identifier: "ko_KR"))
                    }
                } footer: {
                    Text("이 방문의 예정 날짜입니다. AI 리포트 생성 시 이 날짜 기준으로 분석 기간을 계산합니다.")
                }

                // 다음 방문
                Section {
                    Toggle("다음 방문 예약", isOn: $hasNextVisit)
                    if hasNextVisit {
                        DatePicker(
                            "예정일",
                            selection: $nextVisitDate,
                            in: Date()...,
                            displayedComponents: .date
                        )
                        .environment(\.locale, Locale(identifier: "ko_KR"))
                    }
                } footer: {
                    Text("다음 진료 예약이 있으면 설정하세요.")
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
                    if let visitId = existingVisit?.id {
                        healthVM.cancelHospitalReminder(visitId: visitId)
                    }
                    onDelete?()
                    dismiss()
                }
            } message: {
                Text("이 병원 기록을 삭제하시겠습니까?")
            }
        }
    }
}

import SwiftUI
import Charts

struct GrowthView: View {
    @Environment(BabyViewModel.self) var babyVM
    @Environment(AuthViewModel.self) var authVM

    @State var growthVM = GrowthViewModel()
    @State var showAddRecord = false
    @State var editingRecord: GrowthRecord?
    @State var showDeleteConfirm = false
    @State var recordToDelete: GrowthRecord?

    // Form
    @State var height: String = ""
    @State var weight: String = ""
    @State var headCircumference: String = ""
    @State var recordDate = Date()

    @State var saveError: String?

    // Expanded chart state
    @State var expandedWeight = false
    @State var expandedHeight = false
    @State var expandedHead = false

    var records: [GrowthRecord] { growthVM.records }
    var isLoading: Bool { growthVM.isLoading }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Text("이 성장 기록은 참고용이며 의학적 진단을 대체하지 않습니다.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if records.isEmpty && !isLoading {
                        EmptyStateView(
                            icon: "chart.line.uptrend.xyaxis",
                            title: "성장 기록 없음",
                            message: "아기의 성장 기록을 추가해보세요",
                            actionTitle: "기록 추가"
                        ) {
                            showAddRecord = true
                        }
                    } else {
                        // Weight Chart
                        if records.contains(where: { $0.weight != nil }) {
                            chartSection(
                                title: "몸무게 (kg)",
                                icon: "scalemass.fill",
                                color: AppColors.feedingColor,
                                data: records.compactMap { r in
                                    r.weight.map { (r.date, $0) }
                                },
                                metric: .weight,
                                isExpanded: $expandedWeight
                            )
                        }

                        // Height Chart
                        if records.contains(where: { $0.height != nil }) {
                            chartSection(
                                title: "키 (cm)",
                                icon: "ruler.fill",
                                color: AppColors.sleepColor,
                                data: records.compactMap { r in
                                    r.height.map { (r.date, $0) }
                                },
                                metric: .height,
                                isExpanded: $expandedHeight
                            )
                        }

                        // Head Circumference Chart
                        if records.contains(where: { $0.headCircumference != nil }) {
                            chartSection(
                                title: "머리둘레 (cm)",
                                icon: "circle.dashed",
                                color: AppColors.healthColor,
                                data: records.compactMap { r in
                                    r.headCircumference.map { (r.date, $0) }
                                },
                                metric: .headCircumference,
                                isExpanded: $expandedHead
                            )
                        }

                        // Records List
                        VStack(alignment: .leading, spacing: 8) {
                            Text("기록 목록")
                                .font(.headline)
                                .padding(.horizontal)

                            ForEach(records) { record in
                                recordRow(record)
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("성장 기록")
            .toolbar {
                Button {
                    showAddRecord = true
                } label: {
                    Image(systemName: "plus")
                }
            }
            .sheet(isPresented: $showAddRecord, onDismiss: resetForm) {
                addRecordSheet
            }
            .sheet(item: $editingRecord, onDismiss: resetForm) { record in
                editRecordSheet(record)
            }
            .confirmationDialog("기록을 삭제하시겠습니까?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("삭제", role: .destructive) {
                    if let record = recordToDelete {
                        Task { await deleteRecord(record) }
                    }
                }
                Button("취소", role: .cancel) {
                    recordToDelete = nil
                }
            }
            .task { await loadRecords() }
            .onChange(of: babyVM.selectedBaby?.id) {
                Task { await loadRecords() }
            }
            .alert("오류", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
                Button("확인", role: .cancel) { }
            } message: {
                Text(saveError ?? "")
            }
        }
    }

    // MARK: - Data

    func loadRecords() async {
        guard let userId = babyVM.resolvedUserId(auth: authVM),
              let babyId = babyVM.selectedBaby?.id else { return }
        await growthVM.loadRecords(userId: userId, babyId: babyId)
    }

    func startEditing(_ record: GrowthRecord) {
        recordDate = record.date
        weight = record.weight.map { String($0) } ?? ""
        height = record.height.map { String($0) } ?? ""
        headCircumference = record.headCircumference.map { String($0) } ?? ""
        editingRecord = record
    }

    func resetForm() {
        height = ""
        weight = ""
        headCircumference = ""
        recordDate = Date()
    }

    func saveNewRecord() async {
        guard let userId = babyVM.resolvedUserId(auth: authVM),
              let babyId = babyVM.selectedBaby?.id else { return }

        // 체중 검증
        if let w = Double(weight) {
            guard (0.5...30).contains(w) else {
                saveError = "몸무게는 0.5~30kg 범위여야 합니다"
                return
            }
        }

        // 키 검증
        if let h = Double(height) {
            guard (30...130).contains(h) else {
                saveError = "키는 30~130cm 범위여야 합니다"
                return
            }
        }

        // 머리둘레 검증
        if let hc = Double(headCircumference) {
            guard (20...60).contains(hc) else {
                saveError = "머리둘레는 20~60cm 범위여야 합니다"
                return
            }
        }

        let record = GrowthRecord(
            babyId: babyId,
            date: recordDate,
            height: Double(height),
            weight: Double(weight),
            headCircumference: Double(headCircumference)
        )

        do {
            try await growthVM.saveRecord(record, userId: userId)
            showAddRecord = false

            // 성장 속도 알림 체크
            if let baby = babyVM.selectedBaby {
                growthVM.scheduleGrowthVelocityAlert(baby: baby)
            }
        } catch {
            saveError = "저장에 실패했습니다: \(error.localizedDescription)"
        }
    }

    func updateRecord(_ original: GrowthRecord) async {
        guard let userId = babyVM.resolvedUserId(auth: authVM) else { return }

        // 체중 검증
        if let w = Double(weight) {
            guard (0.5...30).contains(w) else {
                saveError = "몸무게는 0.5~30kg 범위여야 합니다"
                return
            }
        }

        // 키 검증
        if let h = Double(height) {
            guard (30...130).contains(h) else {
                saveError = "키는 30~130cm 범위여야 합니다"
                return
            }
        }

        // 머리둘레 검증
        if let hc = Double(headCircumference) {
            guard (20...60).contains(hc) else {
                saveError = "머리둘레는 20~60cm 범위여야 합니다"
                return
            }
        }

        let updated = GrowthRecord(
            id: original.id,
            babyId: original.babyId,
            date: recordDate,
            height: Double(height),
            weight: Double(weight),
            headCircumference: Double(headCircumference),
            note: original.note,
            createdAt: original.createdAt
        )

        do {
            try await growthVM.updateRecord(updated, userId: userId)
            editingRecord = nil
        } catch {
            saveError = "수정에 실패했습니다: \(error.localizedDescription)"
        }
    }

    func deleteRecord(_ record: GrowthRecord) async {
        guard let userId = babyVM.resolvedUserId(auth: authVM),
              let babyId = babyVM.selectedBaby?.id else { return }

        do {
            try await growthVM.deleteRecord(record, userId: userId, babyId: babyId)
            recordToDelete = nil
        } catch {
            saveError = "삭제에 실패했습니다: \(error.localizedDescription)"
        }
    }
}

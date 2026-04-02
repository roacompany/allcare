import SwiftUI
import Charts

struct GrowthView: View {
    @Environment(BabyViewModel.self) private var babyVM
    @Environment(AuthViewModel.self) private var authVM

    @State private var records: [GrowthRecord] = []
    @State private var isLoading = false
    @State private var showAddRecord = false
    @State private var editingRecord: GrowthRecord?
    @State private var showDeleteConfirm = false
    @State private var recordToDelete: GrowthRecord?

    // Form
    @State private var height: String = ""
    @State private var weight: String = ""
    @State private var headCircumference: String = ""
    @State private var recordDate = Date()

    @State private var saveError: String?

    // Expanded chart state
    @State private var expandedWeight = false
    @State private var expandedHeight = false
    @State private var expandedHead = false

    private let firestoreService = FirestoreService.shared

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

    // MARK: - Chart Section

    private func chartSection(
        title: String,
        icon: String,
        color: Color,
        data: [(Date, Double)],
        metric: GrowthMetric,
        isExpanded: Binding<Bool>
    ) -> some View {
        let baby = babyVM.selectedBaby
        let latestPercentile: Double? = {
            guard let baby, let last = data.last else { return nil }
            let months = ageMonths(from: baby.birthDate, to: last.0)
            return PercentileCalculator.percentile(
                value: last.1,
                ageMonths: months,
                gender: baby.gender,
                metric: metric
            )
        }()

        let velocityResult: GrowthVelocityResult? = {
            guard let baby else { return nil }
            return PercentileCalculator.growthVelocity(
                records: records,
                metric: metric,
                gender: baby.gender,
                birthDate: baby.birthDate
            )
        }()

        return VStack(alignment: .leading, spacing: 12) {
            // Title row with percentile badge
            HStack(alignment: .center, spacing: 8) {
                Label(title, systemImage: icon)
                    .font(.headline)
                    .foregroundStyle(color)

                if let p = latestPercentile {
                    Text("\(percentileLabel(p))")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(.blue.opacity(0.1)))
                        .foregroundStyle(.blue)
                }

                Spacer()
            }

            // Base 180px chart
            Chart(data, id: \.0) { item in
                LineMark(
                    x: .value("날짜", item.0, unit: .day),
                    y: .value("값", item.1)
                )
                .foregroundStyle(color)
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("날짜", item.0, unit: .day),
                    y: .value("값", item.1)
                )
                .foregroundStyle(color)
            }
            .frame(height: 180)

            // Velocity indicator (shown when result is available)
            if let v = velocityResult {
                velocityIndicator(v)
            }

            // Expand button
            if baby != nil {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isExpanded.wrappedValue.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isExpanded.wrappedValue ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                        Text("백분위 차트 \(isExpanded.wrappedValue ? "닫기" : "보기")")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }

                // Expanded percentile chart
                if isExpanded.wrappedValue {
                    expandedChart(data: data, metric: metric, color: color, baby: baby!)
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    // MARK: - Velocity Indicator

    @ViewBuilder
    private func velocityIndicator(_ result: GrowthVelocityResult) -> some View {
        let prevLabel = percentileLabel(result.previousPercentile)
        let currLabel = percentileLabel(result.currentPercentile)

        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                // Arrow icon
                let (iconName, iconColor): (String, Color) = {
                    switch result.changeDirection {
                    case .increasing: return ("arrow.up.circle.fill", .green)
                    case .decreasing: return ("arrow.down.circle.fill", .orange)
                    case .stable:     return ("minus.circle.fill", .secondary)
                    }
                }()

                Image(systemName: iconName)
                    .foregroundStyle(iconColor)
                    .font(.caption)

                let arrowChar: String = {
                    switch result.changeDirection {
                    case .increasing: return "↑"
                    case .decreasing: return "↓"
                    case .stable:     return "→"
                    }
                }()

                Text("지난 측정 대비 백분위 \(prevLabel) → \(currLabel) \(arrowChar)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Significant decrease banner
            if result.isSignificant && result.changeDirection == .decreasing {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Text("성장률 변화가 감지되었습니다. 소아과 상담을 권장합니다.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.orange.opacity(0.1))
                )

                Text("이 정보는 참고용이며 의학적 진단을 대체하지 않습니다.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Expanded Percentile Chart

    private func expandedChart(
        data: [(Date, Double)],
        metric: GrowthMetric,
        color: Color,
        baby: Baby
    ) -> some View {
        let referencePctiles: [Double] = [3, 15, 50, 85, 97]

        // Build reference line points by month 0-24
        // Use baby.birthDate as origin; x-axis = date
        struct RefPoint: Identifiable {
            let id: String
            let date: Date
            let value: Double
            let label: String
        }

        var refLines: [(label: String, points: [RefPoint])] = []
        for p in referencePctiles {
            var pts: [RefPoint] = []
            for month in 0...24 {
                let date = Calendar.current.date(
                    byAdding: .month, value: month, to: baby.birthDate
                ) ?? baby.birthDate
                if let val = PercentileCalculator.referenceValue(
                    percentile: p,
                    ageMonths: month,
                    gender: baby.gender,
                    metric: metric
                ) {
                    pts.append(RefPoint(id: "\(Int(p))th-\(month)", date: date, value: val, label: "\(Int(p))th"))
                }
            }
            refLines.append((label: "\(Int(p))th", points: pts))
        }

        return VStack(alignment: .leading, spacing: 6) {
            Chart {
                // WHO reference lines
                ForEach(Array(refLines.enumerated()), id: \.offset) { _, line in
                    ForEach(line.points) { pt in
                        LineMark(
                            x: .value("날짜", pt.date, unit: .month),
                            y: .value(line.label, pt.value),
                            series: .value("계열", line.label)
                        )
                        .foregroundStyle(
                            line.label == "50th"
                                ? Color.secondary.opacity(0.5)
                                : Color.secondary.opacity(0.3)
                        )
                        .lineStyle(StrokeStyle(dash: [4, 4]))
                    }
                }

                // Child data
                ForEach(data, id: \.0) { item in
                    LineMark(
                        x: .value("날짜", item.0, unit: .day),
                        y: .value("값", item.1),
                        series: .value("계열", "아이")
                    )
                    .foregroundStyle(color)
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("날짜", item.0, unit: .day),
                        y: .value("값", item.1)
                    )
                    .foregroundStyle(color)
                }
            }
            .frame(height: 280)

            // Reference line legend
            HStack(spacing: 12) {
                ForEach(referencePctiles, id: \.self) { p in
                    Text("\(Int(p))th")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("WHO 2006")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            // Disclaimer
            Text("이 성장 기록은 참고용이며 의학적 진단을 대체하지 않습니다.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Record Row

    @ViewBuilder
    private func recordRow(_ record: GrowthRecord) -> some View {
        let baby = babyVM.selectedBaby
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(DateFormatters.shortDate.string(from: record.date))
                    .font(.subheadline)

                Spacer()

                HStack(spacing: 6) {
                    if let w = record.weight {
                        VStack(alignment: .trailing, spacing: 1) {
                            Text(String(format: "%.1fkg", w))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            if let baby,
                               let p = PercentileCalculator.percentile(
                                value: w,
                                ageMonths: ageMonths(from: baby.birthDate, to: record.date),
                                gender: baby.gender,
                                metric: .weight
                               ) {
                                Text(percentileLabel(p))
                                    .font(.caption2)
                                    .foregroundStyle(.blue)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                        }
                    }
                    if let h = record.height {
                        VStack(alignment: .trailing, spacing: 1) {
                            Text(String(format: "%.1fcm", h))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            if let baby,
                               let p = PercentileCalculator.percentile(
                                value: h,
                                ageMonths: ageMonths(from: baby.birthDate, to: record.date),
                                gender: baby.gender,
                                metric: .height
                               ) {
                                Text(percentileLabel(p))
                                    .font(.caption2)
                                    .foregroundStyle(.blue)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                        }
                    }
                    if let hc = record.headCircumference {
                        VStack(alignment: .trailing, spacing: 1) {
                            Text(String(format: "%.1fcm", hc))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            if let baby,
                               let p = PercentileCalculator.percentile(
                                value: hc,
                                ageMonths: ageMonths(from: baby.birthDate, to: record.date),
                                gender: baby.gender,
                                metric: .headCircumference
                               ) {
                                Text(percentileLabel(p))
                                    .font(.caption2)
                                    .foregroundStyle(.blue)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture {
            startEditing(record)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                recordToDelete = record
                showDeleteConfirm = true
            } label: {
                Label("삭제", systemImage: "trash")
            }
        }
    }

    // MARK: - Helpers

    private func percentileLabel(_ p: Double) -> String {
        let rounded = Int(p.rounded())
        return "\(rounded)th"
    }

    private func ageMonths(from birthDate: Date, to date: Date) -> Int {
        return max(0, min(24, Int(date.timeIntervalSince(birthDate) / (86400 * 30.4375))))
    }

    // MARK: - Add Record Sheet

    private var addRecordSheet: some View {
        NavigationStack {
            Form {
                Section("날짜") {
                    DatePicker("날짜", selection: $recordDate, displayedComponents: .date)
                        .environment(\.locale, Locale(identifier: "ko_KR"))
                }

                Section("측정값") {
                    HStack {
                        Text("몸무게")
                        Spacer()
                        TextField("kg", text: $weight)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    HStack {
                        Text("키")
                        Spacer()
                        TextField("cm", text: $height)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    HStack {
                        Text("머리둘레")
                        Spacer()
                        TextField("cm", text: $headCircumference)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                }
            }
            .navigationTitle("성장 기록 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { showAddRecord = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        Task { await saveNewRecord() }
                    }
                    .disabled(weight.isEmpty && height.isEmpty && headCircumference.isEmpty)
                }
            }
        }
    }

    // MARK: - Edit Record Sheet

    private func editRecordSheet(_ record: GrowthRecord) -> some View {
        NavigationStack {
            Form {
                Section("날짜") {
                    DatePicker("날짜", selection: $recordDate, displayedComponents: .date)
                        .environment(\.locale, Locale(identifier: "ko_KR"))
                }

                Section("측정값") {
                    HStack {
                        Text("몸무게")
                        Spacer()
                        TextField("kg", text: $weight)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    HStack {
                        Text("키")
                        Spacer()
                        TextField("cm", text: $height)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    HStack {
                        Text("머리둘레")
                        Spacer()
                        TextField("cm", text: $headCircumference)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                }
            }
            .navigationTitle("성장 기록 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { editingRecord = nil }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        Task { await updateRecord(record) }
                    }
                    .disabled(weight.isEmpty && height.isEmpty && headCircumference.isEmpty)
                }
            }
        }
    }

    // MARK: - Data

    private func loadRecords() async {
        guard let currentUserId = authVM.currentUserId,
              let babyId = babyVM.selectedBaby?.id else { return }
        let dataUserId = babyVM.dataUserId(currentUserId: currentUserId) ?? currentUserId
        isLoading = true
        records = (try? await firestoreService.fetchGrowthRecords(userId: dataUserId, babyId: babyId)) ?? []
        isLoading = false
    }

    private func startEditing(_ record: GrowthRecord) {
        recordDate = record.date
        weight = record.weight.map { String($0) } ?? ""
        height = record.height.map { String($0) } ?? ""
        headCircumference = record.headCircumference.map { String($0) } ?? ""
        editingRecord = record
    }

    private func resetForm() {
        height = ""
        weight = ""
        headCircumference = ""
        recordDate = Date()
    }

    private func saveNewRecord() async {
        guard let currentUserId = authVM.currentUserId,
              let babyId = babyVM.selectedBaby?.id else { return }
        let userId = babyVM.dataUserId(currentUserId: currentUserId) ?? currentUserId

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
            try await firestoreService.saveGrowthRecord(record, userId: userId)
            records.append(record)
            records.sort { $0.date < $1.date }
            showAddRecord = false

            // 성장 속도 알림 체크
            checkAndNotifyGrowthVelocity()
        } catch {
            saveError = "저장에 실패했습니다: \(error.localizedDescription)"
        }
    }

    private func checkAndNotifyGrowthVelocity() {
        guard let baby = babyVM.selectedBaby else { return }
        let babyName = baby.name

        for metric in [GrowthMetric.weight, .height, .headCircumference] {
            if let result = PercentileCalculator.growthVelocity(
                records: records,
                metric: metric,
                gender: baby.gender,
                birthDate: baby.birthDate
            ), result.isSignificant {
                Task { @MainActor in
                    await NotificationService.shared.scheduleGrowthVelocityAlert(babyName: babyName)
                }
                break
            }
        }
    }

    private func updateRecord(_ original: GrowthRecord) async {
        guard let currentUserId = authVM.currentUserId else { return }
        let userId = babyVM.dataUserId(currentUserId: currentUserId) ?? currentUserId

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
            try await firestoreService.updateGrowthRecord(updated, userId: userId)
            if let idx = records.firstIndex(where: { $0.id == original.id }) {
                records[idx] = updated
                records.sort { $0.date < $1.date }
            }
            editingRecord = nil
        } catch {
            saveError = "수정에 실패했습니다: \(error.localizedDescription)"
        }
    }

    private func deleteRecord(_ record: GrowthRecord) async {
        guard let currentUserId = authVM.currentUserId,
              let babyId = babyVM.selectedBaby?.id else { return }
        let userId = babyVM.dataUserId(currentUserId: currentUserId) ?? currentUserId

        do {
            try await firestoreService.deleteGrowthRecord(record.id, userId: userId, babyId: babyId)
            records.removeAll { $0.id == record.id }
            recordToDelete = nil
        } catch {
            saveError = "삭제에 실패했습니다: \(error.localizedDescription)"
        }
    }
}

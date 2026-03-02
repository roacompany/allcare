import SwiftUI
import Charts

struct GrowthView: View {
    @Environment(BabyViewModel.self) private var babyVM
    @Environment(AuthViewModel.self) private var authVM

    @State private var records: [GrowthRecord] = []
    @State private var isLoading = false
    @State private var showAddRecord = false

    // Form
    @State private var height: String = ""
    @State private var weight: String = ""
    @State private var headCircumference: String = ""
    @State private var recordDate = Date()

    private let firestoreService = FirestoreService.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
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
                                color: Color(hex: "FF9FB5"),
                                data: records.compactMap { r in
                                    r.weight.map { (r.date, $0) }
                                }
                            )
                        }

                        // Height Chart
                        if records.contains(where: { $0.height != nil }) {
                            chartSection(
                                title: "키 (cm)",
                                icon: "ruler.fill",
                                color: Color(hex: "9FB5FF"),
                                data: records.compactMap { r in
                                    r.height.map { (r.date, $0) }
                                }
                            )
                        }

                        // Head Circumference Chart
                        if records.contains(where: { $0.headCircumference != nil }) {
                            chartSection(
                                title: "머리둘레 (cm)",
                                icon: "circle.dashed",
                                color: Color(hex: "9FDFBF"),
                                data: records.compactMap { r in
                                    r.headCircumference.map { (r.date, $0) }
                                }
                            )
                        }

                        // Records List
                        VStack(alignment: .leading, spacing: 8) {
                            Text("기록 목록")
                                .font(.headline)
                                .padding(.horizontal)

                            ForEach(records) { record in
                                HStack {
                                    Text(DateFormatters.shortDate.string(from: record.date))
                                        .font(.subheadline)

                                    Spacer()

                                    if let w = record.weight {
                                        Text(String(format: "%.1fkg", w))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    if let h = record.height {
                                        Text(String(format: "%.1fcm", h))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 6)
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
            .sheet(isPresented: $showAddRecord) {
                addRecordSheet
            }
            .task { await loadRecords() }
        }
    }

    // MARK: - Chart Section

    private func chartSection(title: String, icon: String, color: Color, data: [(Date, Double)]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(color)

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
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
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
                        Task { await saveRecord() }
                    }
                    .disabled(weight.isEmpty && height.isEmpty && headCircumference.isEmpty)
                }
            }
        }
    }

    // MARK: - Data

    private func loadRecords() async {
        guard let userId = authVM.currentUserId,
              let babyId = babyVM.selectedBaby?.id else { return }
        isLoading = true
        records = (try? await firestoreService.fetchGrowthRecords(userId: userId, babyId: babyId)) ?? []
        isLoading = false
    }

    private func saveRecord() async {
        guard let userId = authVM.currentUserId,
              let babyId = babyVM.selectedBaby?.id else { return }

        let record = GrowthRecord(
            babyId: babyId,
            date: recordDate,
            height: Double(height),
            weight: Double(weight),
            headCircumference: Double(headCircumference)
        )

        try? await firestoreService.saveGrowthRecord(record, userId: userId)
        records.append(record)
        records.sort { $0.date < $1.date }
        showAddRecord = false
        height = ""
        weight = ""
        headCircumference = ""
    }
}

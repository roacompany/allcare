import SwiftUI

extension GrowthView {

    // MARK: - Record Row

    @ViewBuilder
    func recordRow(_ record: GrowthRecord) -> some View {
        let baby = babyVM.selectedBaby
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(DateFormatters.shortDate.string(from: record.date))
                    .font(.subheadline)
                Spacer()
                HStack(spacing: 6) {
                    if let w = record.weight {
                        recordMetricView(
                            value: String(format: "%.1fkg", w),
                            baby: baby, rawValue: w, recordDate: record.date, metric: .weight
                        )
                    }
                    if let h = record.height {
                        recordMetricView(
                            value: String(format: "%.1fcm", h),
                            baby: baby, rawValue: h, recordDate: record.date, metric: .height
                        )
                    }
                    if let hc = record.headCircumference {
                        recordMetricView(
                            value: String(format: "%.1fcm", hc),
                            baby: baby, rawValue: hc, recordDate: record.date, metric: .headCircumference
                        )
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        // 지우기는 수정 창 맨 아래 「기록 삭제」에서 — 이 줄은 List 가 아닌 칸이라 옆으로 밀기가 안 먹는다(2026-11-07)
        .onTapGesture {
            startEditing(record)
        }
    }

    /// 단일 성장 지표(값 + 백분위)를 표시하는 헬퍼 뷰
    @ViewBuilder
    private func recordMetricView(
        value: String,
        baby: Baby?,
        rawValue: Double,
        recordDate: Date,
        metric: GrowthMetric
    ) -> some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(value)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            if let baby,
               let p = PercentileCalculator.percentile(
                value: rawValue,
                ageMonths: ageMonths(from: baby.birthDate, to: recordDate),
                gender: baby.gender,
                metric: metric
               ) {
                Text(percentileLabel(p))
                    .font(.caption2)
                    .foregroundStyle(.blue)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
    }

    // MARK: - Add Record Sheet

    var addRecordSheet: some View {
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

    func editRecordSheet(_ record: GrowthRecord) -> some View {
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

                // 삭제 — 병원 기록 수정 창과 같은 모양
                Section {
                    Button(role: .destructive) {
                        recordToDelete = record
                        showDeleteConfirm = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("기록 삭제")
                            Spacer()
                        }
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
            // 확인 창은 수정 창 위에 떠야 한다(뒤 화면에 두면 시트에 가려 안 뜬다)
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
        }
    }
}

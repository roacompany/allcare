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
}

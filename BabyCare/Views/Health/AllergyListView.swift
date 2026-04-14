import SwiftUI

struct AllergyListView: View {
    @Environment(AuthViewModel.self) private var authVM
    @Environment(BabyViewModel.self) private var babyVM
    @Environment(HealthViewModel.self) private var healthVM

    @State private var records: [AllergyRecord] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showAddSheet = false
    @State private var editingRecord: AllergyRecord?
    @State private var savedMessage: String?

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if records.isEmpty {
                EmptyStateView(
                    icon: "leaf.circle.fill",
                    title: "알레르기 기록 없음",
                    message: "알레르기 반응이 있었다면 기록해보세요",
                    actionTitle: "기록 추가"
                ) {
                    showAddSheet = true
                }
            } else {
                allergyList
            }
        }
        .navigationTitle("알레르기 기록")
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
            AddAllergyView { newRecord in
                records.insert(newRecord, at: 0)
                withAnimation { savedMessage = "\(newRecord.allergenName) 기록 저장됨" }
            }
        }
        .sheet(item: $editingRecord) { record in
            AddAllergyView(editingRecord: record) { updatedRecord in
                if let index = records.firstIndex(where: { $0.id == updatedRecord.id }) {
                    records[index] = updatedRecord
                }
                withAnimation { savedMessage = "\(updatedRecord.allergenName) 기록 수정됨" }
            }
        }
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
        .alert("오류", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("확인") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .task {
            await loadRecords()
        }
    }

    // MARK: - Allergy List

    private var allergyList: some View {
        List {
            let severeRecords = records.filter { $0.severity == .severe }
            let moderateRecords = records.filter { $0.severity == .moderate }
            let mildRecords = records.filter { $0.severity == .mild }

            if !severeRecords.isEmpty {
                Section {
                    ForEach(severeRecords) { record in
                        AllergyRow(record: record)
                            .contentShape(Rectangle())
                            .onTapGesture { editingRecord = record }
                    }
                    .onDelete { indexSet in
                        deleteRecords(from: severeRecords, at: indexSet)
                    }
                } header: {
                    SectionHeaderLabel(title: "중증", color: .red)
                }
            }

            if !moderateRecords.isEmpty {
                Section {
                    ForEach(moderateRecords) { record in
                        AllergyRow(record: record)
                            .contentShape(Rectangle())
                            .onTapGesture { editingRecord = record }
                    }
                    .onDelete { indexSet in
                        deleteRecords(from: moderateRecords, at: indexSet)
                    }
                } header: {
                    SectionHeaderLabel(title: "중등", color: .orange)
                }
            }

            if !mildRecords.isEmpty {
                Section {
                    ForEach(mildRecords) { record in
                        AllergyRow(record: record)
                            .contentShape(Rectangle())
                            .onTapGesture { editingRecord = record }
                    }
                    .onDelete { indexSet in
                        deleteRecords(from: mildRecords, at: indexSet)
                    }
                } header: {
                    SectionHeaderLabel(title: "경증", color: .green)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Helpers

    private func loadRecords() async {
        guard let currentUserId = authVM.currentUserId,
              let baby = babyVM.selectedBaby else { return }
        let dataUserId = babyVM.dataUserId(currentUserId: currentUserId) ?? currentUserId
        isLoading = true
        await healthVM.loadAllergyRecords(userId: dataUserId, babyId: baby.id)
        records = healthVM.allergyRecords
        if let msg = healthVM.errorMessage { errorMessage = msg }
        isLoading = false
    }

    private func deleteRecords(from source: [AllergyRecord], at indexSet: IndexSet) {
        guard let currentUserId = authVM.currentUserId,
              let baby = babyVM.selectedBaby else { return }
        let dataUserId = babyVM.dataUserId(currentUserId: currentUserId) ?? currentUserId
        let toDelete = indexSet.map { source[$0] }
        Task {
            for record in toDelete {
                await healthVM.deleteAllergyRecord(userId: dataUserId, babyId: baby.id, recordId: record.id)
                records.removeAll { $0.id == record.id }
            }
            if let msg = healthVM.errorMessage { errorMessage = msg }
        }
    }
}

// MARK: - Allergy Row

private struct AllergyRow: View {
    let record: AllergyRecord

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "leaf.circle.fill")
                .foregroundStyle(severityColor)
                .font(.title3)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(record.allergenName)
                    .font(.subheadline.weight(.medium))

                HStack(spacing: 6) {
                    Text(record.reactionType.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if !record.symptoms.isEmpty {
                        Text("·")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(record.symptoms.prefix(2).joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Text(DateFormatters.shortDate.string(from: record.date))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            SeverityBadge(severity: record.severity)
        }
        .padding(.vertical, 4)
    }

    private var severityColor: Color {
        switch record.severity {
        case .mild: return .green
        case .moderate: return .orange
        case .severe: return .red
        }
    }
}

// MARK: - Severity Badge

private struct SeverityBadge: View {
    let severity: AllergySeverity

    var body: some View {
        Text(severity.displayName)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(badgeColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(badgeColor.opacity(0.15))
            .clipShape(Capsule())
    }

    private var badgeColor: Color {
        switch severity {
        case .mild: return .green
        case .moderate: return .orange
        case .severe: return .red
        }
    }
}

// MARK: - Section Header Label

private struct SectionHeaderLabel: View {
    let title: String
    let color: Color

    var body: some View {
        Text(title)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(color)
            .textCase(nil)
    }
}

import SwiftUI

struct HospitalVisitListView: View {
    @Environment(HealthViewModel.self) private var healthVM
    @Environment(AuthViewModel.self) private var authVM
    @Environment(BabyViewModel.self) private var babyVM
    @State private var showAddSheet = false
    @State private var selectedVisit: HospitalVisit?
    @State private var reportVisit: HospitalVisit?

    @State private var reportVM = HospitalReportViewModel()
    @State private var savedMessage: String?

    var body: some View {
        Group {
            if healthVM.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                visitList
            }
        }
    }

    private func saveVisit(_ visit: HospitalVisit) {
        guard let currentUserId = authVM.currentUserId else { return }
        let dataUserId = babyVM.dataUserId(currentUserId: currentUserId) ?? currentUserId
        Task {
            await healthVM.saveHospitalVisit(visit, userId: dataUserId)
            if healthVM.errorMessage == nil {
                withAnimation { savedMessage = "\(visit.hospitalName) 저장됨" }
            }
        }
    }

    private func deleteVisit(_ visit: HospitalVisit) {
        guard let currentUserId = authVM.currentUserId else { return }
        let dataUserId = babyVM.dataUserId(currentUserId: currentUserId) ?? currentUserId
        Task { await healthVM.deleteHospitalVisit(visit, userId: dataUserId) }
    }

    private var totalCost: Int {
        healthVM.hospitalVisits.compactMap(\.cost).reduce(0, +)
    }

    @ViewBuilder
    private var visitList: some View {
        List {
            if totalCost > 0 {
                Section {
                    HStack {
                        Label("총 진료비", systemImage: "wonsign.circle")
                        Spacer()
                        Text("₩\(totalCost.formatted())")
                            .font(.headline)
                    }
                }
            }
            upcomingSection
            pastSection
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
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showAddSheet = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            HospitalVisitFormSheet(visit: nil) { visit in saveVisit(visit) }
        }
        .sheet(item: $selectedVisit) { visit in
            HospitalVisitFormSheet(visit: visit) { updated in saveVisit(updated) } onDelete: {
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
        .sheet(item: $reportVisit) { visit in
            HospitalReportSheet(
                visit: visit,
                reportVM: reportVM,
                userId: babyVM.dataUserId(currentUserId: authVM.currentUserId) ?? authVM.currentUserId ?? "",
                baby: babyVM.selectedBaby,
                previousVisitDate: previousVisitDate(before: visit)
            )
        }
    }

    @ViewBuilder
    private var upcomingSection: some View {
        if !healthVM.upcomingVisits.isEmpty {
            Section("예정된 방문") {
                ForEach(healthVM.upcomingVisits) { visit in
                    HospitalVisitRow(visit: visit)
                        .contentShape(Rectangle())
                        .onTapGesture { selectedVisit = visit }
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            Button { startReport(for: visit) } label: {
                                Label("AI 리포트", systemImage: "brain.fill")
                            }
                            .tint(.purple)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) { deleteVisit(visit) } label: {
                                Label("삭제", systemImage: "trash")
                            }
                        }
                }
            }
        }
    }

    @ViewBuilder
    private var pastSection: some View {
        if !healthVM.pastVisits.isEmpty {
            Section("지난 기록") {
                ForEach(healthVM.pastVisits) { visit in
                    HospitalVisitRow(visit: visit)
                        .contentShape(Rectangle())
                        .onTapGesture { selectedVisit = visit }
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            Button { startReport(for: visit) } label: {
                                Label("AI 리포트", systemImage: "brain.fill")
                            }
                            .tint(.purple)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) { deleteVisit(visit) } label: {
                                Label("삭제", systemImage: "trash")
                            }
                        }
                }
            }
        }
    }

    private func startReport(for visit: HospitalVisit) {
        guard !reportVM.state.isLoading else { return }
        reportVM.reset()
        // 체크리스트·PDF 생성에 필요한 데이터 주입 (vaccinations은 healthVM에서 전달)
        reportVM.vaccinations = healthVM.vaccinations
        reportVisit = visit
    }

    private func previousVisitDate(before visit: HospitalVisit) -> Date? {
        healthVM.pastVisits
            .filter { $0.visitDate < visit.visitDate }
            .sorted { $0.visitDate > $1.visitDate }
            .first?
            .visitDate
    }
}

import SwiftUI
import Charts

struct StatsView: View {
    @Environment(StatsViewModel.self) private var statsVM
    @Environment(BabyViewModel.self) private var babyVM
    @Environment(AuthViewModel.self) private var authVM

    @State private var exportURL: URL?
    @State private var showShareSheet = false
    @State private var showExportOptions = false
    @State private var isGeneratingPDF = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Period Picker
                    Picker("기간", selection: Bindable(statsVM).selectedPeriod) {
                        ForEach(StatsViewModel.StatsPeriod.allCases, id: \.self) { period in
                            Text(period.rawValue).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    if statsVM.isLoading {
                        ProgressView()
                            .padding(60)
                    } else {
                        // Feeding Chart
                        feedingChart

                        // Sleep Chart
                        sleepChart

                        // Diaper Chart
                        diaperChart
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("통계")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        PatternReportView()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "waveform.path.ecg")
                            Text("패턴 분석")
                        }
                        .font(.subheadline)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            let babyName = babyVM.selectedBaby?.name ?? "아기"
                            if let url = statsVM.generateCSVExport(activities: statsVM.weeklyActivities, babyName: babyName) {
                                exportURL = url
                                showShareSheet = true
                            }
                        } label: {
                            Label("CSV 내보내기", systemImage: "tablecells")
                        }

                        Button {
                            Task { await generatePDFReport() }
                        } label: {
                            Label("PDF 리포트 (소아과용)", systemImage: "doc.richtext")
                        }
                    } label: {
                        if isGeneratingPDF {
                            ProgressView()
                        } else {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                    .disabled(statsVM.weeklyActivities.isEmpty || isGeneratingPDF)
                }
            }
            .task { await loadStats() }
            .onChange(of: statsVM.selectedPeriod) {
                Task { await loadStats() }
            }
            .onChange(of: babyVM.selectedBaby?.id) {
                Task { await loadStats() }
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = exportURL {
                    ShareSheet(items: [url])
                }
            }
        }
    }

    // MARK: - Share Sheet

    private struct ShareSheet: UIViewControllerRepresentable {
        let items: [Any]
        func makeUIViewController(context: Context) -> UIActivityViewController {
            UIActivityViewController(activityItems: items, applicationActivities: nil)
        }
        func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
    }

    // MARK: - Feeding Chart

    private var feedingChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("수유", systemImage: "cup.and.saucer.fill")
                .font(.headline)
                .foregroundStyle(AppColors.feedingColor)

            if statsVM.dailyFeedingCounts.isEmpty {
                Text("데이터 없음")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(height: 120)
                    .frame(maxWidth: .infinity)
            } else {
                Chart(statsVM.dailyFeedingCounts, id: \.date) { item in
                    BarMark(
                        x: .value("날짜", item.date, unit: .day),
                        y: .value("횟수", item.count)
                    )
                    .foregroundStyle(AppColors.feedingColor.gradient)
                    .cornerRadius(4)
                }
                .chartYAxisLabel("회")
                .frame(height: 160)
            }

            if let interval = statsVM.averageFeedingInterval {
                HStack {
                    Text("평균 간격")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(interval.shortDuration)
                        .font(.caption.weight(.medium))
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    // MARK: - Sleep Chart

    private var sleepChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("수면", systemImage: "moon.zzz.fill")
                .font(.headline)
                .foregroundStyle(AppColors.sleepColor)

            if statsVM.dailySleepDurations.isEmpty {
                Text("데이터 없음")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(height: 120)
                    .frame(maxWidth: .infinity)
            } else {
                Chart(statsVM.dailySleepDurations, id: \.date) { item in
                    BarMark(
                        x: .value("날짜", item.date, unit: .day),
                        y: .value("시간", item.hours)
                    )
                    .foregroundStyle(AppColors.sleepColor.gradient)
                    .cornerRadius(4)
                }
                .chartYAxisLabel("시간")
                .frame(height: 160)
            }

            HStack {
                Text("평균 수면")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(String(format: "%.1f시간", statsVM.averageSleepHours))
                    .font(.caption.weight(.medium))
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    // MARK: - Diaper Chart

    private var diaperChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("기저귀", systemImage: "humidity.fill")
                .font(.headline)
                .foregroundStyle(AppColors.diaperColor)

            if statsVM.dailyDiaperCounts.isEmpty {
                Text("데이터 없음")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(height: 120)
                    .frame(maxWidth: .infinity)
            } else {
                Chart(statsVM.dailyDiaperCounts, id: \.date) { item in
                    BarMark(
                        x: .value("날짜", item.date, unit: .day),
                        y: .value("횟수", item.count)
                    )
                    .foregroundStyle(AppColors.diaperColor.gradient)
                    .cornerRadius(4)
                }
                .chartYAxisLabel("회")
                .frame(height: 160)
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    private func loadStats() async {
        guard let currentUserId = authVM.currentUserId,
              let babyId = babyVM.selectedBaby?.id else { return }
        let dataUserId = babyVM.dataUserId(currentUserId: currentUserId) ?? currentUserId
        await statsVM.loadStats(userId: dataUserId, babyId: babyId)
    }

    private func generatePDFReport() async {
        guard let baby = babyVM.selectedBaby,
              let currentUserId = authVM.currentUserId else { return }
        let dataUserId = babyVM.dataUserId(currentUserId: currentUserId) ?? currentUserId

        isGeneratingPDF = true
        defer { isGeneratingPDF = false }

        let periodDays = statsVM.selectedPeriod == .week ? 7 : 30

        let growthRecords = await statsVM.fetchGrowthRecords(userId: dataUserId, babyId: baby.id)

        if let url = statsVM.generatePDFReport(
            baby: baby,
            activities: statsVM.weeklyActivities,
            growthRecords: growthRecords,
            periodDays: periodDays
        ) {
            exportURL = url
            showShareSheet = true
        }
    }
}

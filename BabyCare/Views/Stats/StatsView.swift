import SwiftUI
import Charts

struct StatsView: View {
    @Environment(StatsViewModel.self) private var statsVM
    @Environment(BabyViewModel.self) private var babyVM
    @Environment(AuthViewModel.self) private var authVM

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
            .task { await loadStats() }
            .onChange(of: statsVM.selectedPeriod) {
                Task { await loadStats() }
            }
        }
    }

    // MARK: - Feeding Chart

    private var feedingChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("수유", systemImage: "cup.and.saucer.fill")
                .font(.headline)
                .foregroundStyle(Color(hex: "FF9FB5"))

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
                    .foregroundStyle(Color(hex: "FF9FB5").gradient)
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
                .foregroundStyle(Color(hex: "9FB5FF"))

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
                    .foregroundStyle(Color(hex: "9FB5FF").gradient)
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
                .foregroundStyle(Color(hex: "FFD59F"))

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
                    .foregroundStyle(Color(hex: "FFD59F").gradient)
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
        guard let userId = authVM.currentUserId,
              let babyId = babyVM.selectedBaby?.id else { return }
        await statsVM.loadStats(userId: userId, babyId: babyId)
    }
}

import SwiftUI
import Charts

struct PatternReportView: View {
    @Environment(PatternReportViewModel.self) var vm
    @Environment(BabyViewModel.self) var babyVM
    @Environment(AuthViewModel.self) var authVM

    let feedingColor = AppColors.feedingColor
    let sleepColor = AppColors.sleepColor
    let diaperColor = AppColors.diaperColor
    let healthColor = AppColors.healthColor

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                periodPicker

                if vm.isLoading {
                    ProgressView()
                        .padding(60)
                } else if let report = vm.report {
                    if report.summary.totalRecords == 0 {
                        emptyStateView
                    } else {
                        aiInsightCard
                        feedingSection(report.feeding)
                        sleepSection(report.sleep)
                        diaperSection(report.diaper)
                        healthSection(report.health)
                        summarySection(report.summary)
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("패턴 분석")
        .task { await loadReport() }
        .onChange(of: vm.selectedPeriod) {
            Task { await loadReport() }
        }
    }

    // MARK: - Period Picker

    var periodPicker: some View {
        Picker("기간", selection: Bindable(vm).selectedPeriod) {
            ForEach(PatternReportViewModel.Period.allCases, id: \.self) { period in
                Text(period.rawValue).tag(period)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
    }

    // MARK: - Empty State

    var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text("분석할 데이터가 없습니다")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("활동을 기록하면 패턴을 분석해드려요")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - AI Insight Card

    var aiInsightCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "brain.head.profile.fill")
                    .foregroundStyle(.purple)
                Text("AI 패턴 분석")
                    .font(.headline)
                AIGeneratedLabel()
                Spacer()
            }

            if let insight = vm.aiInsight {
                Text(insight)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineSpacing(4)
            } else if vm.isLoadingAI {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("분석 중...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                if vm.hasAPIKey {
                    Button {
                        Task { await requestAI() }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                            Text("AI 분석 받기")
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.purple.gradient, in: Capsule())
                    }
                } else {
                    Text("설정에서 AI API 키를 입력하면 맞춤 분석을 받을 수 있어요")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let error = vm.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding()
        .background(Color.purple.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }
}

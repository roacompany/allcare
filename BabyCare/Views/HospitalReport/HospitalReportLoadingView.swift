import SwiftUI

// MARK: - 분석 로딩 화면

struct HospitalReportLoadingView: View {
    let state: ReportState

    @State private var dotCount = 0
    private let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // 애니메이션 아이콘
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 100, height: 100)
                Image(systemName: iconName)
                    .font(.system(size: 44))
                    .foregroundStyle(.blue)
                    .symbolEffect(.pulse)
            }

            VStack(spacing: 8) {
                Text(titleText)
                    .font(.headline)

                HStack(spacing: 2) {
                    Text(subtitleText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(String(repeating: ".", count: dotCount + 1))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(width: 20, alignment: .leading)
                }
            }

            // 단계 진행 표시
            VStack(spacing: 12) {
                StepRow(icon: "chart.bar.fill", label: "기록 데이터 수집", done: true)
                StepRow(icon: "waveform.path.ecg", label: "이상 패턴 분석",
                        done: isGenerating || isDone, active: isAnalyzing)
                StepRow(icon: "brain.fill", label: "AI 리포트 생성",
                        done: isDone, active: isGenerating)
            }
            .padding(.horizontal, 40)

            Spacer()
        }
        .onReceive(timer) { _ in
            dotCount = (dotCount + 1) % 3
        }
    }

    private var iconName: String {
        isGenerating ? "brain.fill" : "waveform.path.ecg"
    }

    private var titleText: String {
        isGenerating ? "AI 리포트 생성 중" : "데이터 분석 중"
    }

    private var subtitleText: String {
        isGenerating ? "Claude AI가 리포트를 작성하고 있어요" : "아기의 기록 패턴을 분석하고 있어요"
    }

    private var isAnalyzing: Bool {
        if case .analyzing = state { return true }
        return false
    }

    private var isGenerating: Bool {
        if case .generating = state { return true }
        return false
    }

    private var isDone: Bool {
        if case .done = state { return true }
        return false
    }
}

// MARK: - Step Row

private struct StepRow: View {
    let icon: String
    let label: String
    var done: Bool = false
    var active: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(done ? Color.green.opacity(0.15) :
                          active ? Color.blue.opacity(0.15) : Color.gray.opacity(0.1))
                    .frame(width: 32, height: 32)
                Image(systemName: done ? "checkmark" : icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(done ? .green : active ? .blue : .secondary)
            }
            Text(label)
                .font(.subheadline)
                .foregroundStyle(done || active ? .primary : .secondary)
            Spacer()
        }
    }
}

#Preview {
    HospitalReportLoadingView(state: .analyzing)
}

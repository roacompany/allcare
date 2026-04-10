import SwiftUI
import Charts

// MARK: - CryAnalysisView
// 울음 분석 화면. 마이크 녹음 → AI 분석 → 결과(확률 바) → 저장 흐름.
// 면책 배너 필수, AI 가드레일 금지어 미사용.

struct CryAnalysisView: View {
    @State private var vm = CryAnalysisViewModel()
    @Environment(BabyViewModel.self) private var babyVM
    @Environment(AuthViewModel.self) private var authVM
    @AppStorage("cryAnalysisOnboardingShown") private var onboardingShown = false
    @State private var showOnboardingSheet = false
    @State private var saveMessage: String?

    private var babyId: String {
        babyVM.selectedBaby?.id ?? ""
    }

    private var dataUserId: String {
        babyVM.dataUserId(currentUserId: authVM.currentUserId) ?? authVM.currentUserId ?? ""
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 1. 면책 배너 (항상 표시)
                    DisclaimerBanner()

                    // 2. 페이즈별 메인 콘텐츠
                    phaseContent

                    // 3. 저장 메시지
                    if let msg = saveMessage {
                        Text(msg)
                            .font(.footnote)
                            .foregroundStyle(msg.hasPrefix("저장") ? Color.green : Color.red)
                            .padding(.horizontal)
                            .transition(.opacity)
                    }

                    // 4. 히스토리
                    if !vm.history.isEmpty {
                        HistorySection(history: vm.history)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .navigationTitle("울음 분석")
            .onAppear {
                if !onboardingShown {
                    showOnboardingSheet = true
                }
                if !babyId.isEmpty {
                    Task {
                        try? await vm.loadHistory(babyId: babyId, dataUserId: dataUserId)
                    }
                }
            }
            .onChange(of: vm.phase) { _, newPhase in
                handlePhaseChange(newPhase)
            }
            .sheet(isPresented: $showOnboardingSheet) {
                OnboardingSheet {
                    onboardingShown = true
                    showOnboardingSheet = false
                }
            }
        }
    }

    // MARK: - Phase Content

    @ViewBuilder
    private var phaseContent: some View {
        switch vm.phase {
        case .idle:
            IdlePhaseView {
                Task { await vm.start(babyId: babyId) }
            }

        case .permissionRequired:
            PermissionRequiredView {
                Task { await vm.start(babyId: babyId) }
            }

        case .permissionDenied:
            PermissionDeniedView()

        case .recording(let progress):
            RecordingPhaseView(progress: progress) {
                vm.cancel()
            }

        case .analyzing:
            AnalyzingPhaseView()

        case .result(let record):
            ResultPhaseView(
                record: record,
                onSave: {
                    Task {
                        do {
                            try await vm.save(babyId: babyId, dataUserId: dataUserId, record: record)
                            withAnimation { saveMessage = "저장되었습니다" }
                            try? await vm.loadHistory(babyId: babyId, dataUserId: dataUserId)
                        } catch {
                            withAnimation { saveMessage = "저장 실패: \(error.localizedDescription)" }
                        }
                    }
                },
                onRetry: {
                    saveMessage = nil
                    Task { await vm.start(babyId: babyId) }
                }
            )

        case .error(let msg):
            ErrorPhaseView(message: msg) {
                Task { await vm.start(babyId: babyId) }
            }
        }
    }

    // MARK: - Phase Change Handler

    private func handlePhaseChange(_ phase: CryAnalysisViewModel.Phase) {
        switch phase {
        case .recording:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            UIAccessibility.post(notification: .announcement, argument: "녹음을 시작합니다")
        case .result:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            UIAccessibility.post(notification: .announcement, argument: "분석이 완료되었습니다")
        default:
            break
        }
    }
}

// MARK: - Disclaimer Banner

private struct DisclaimerBanner: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(Color.orange)
            Text("본 기능은 의료 진단이 아닌 참고 정보입니다. AI 추정이며 정확도가 제한적입니다.")
                .font(.subheadline)
                .foregroundStyle(Color.primary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.orange.opacity(0.4), lineWidth: 1)
        )
    }
}

// MARK: - Idle Phase

private struct IdlePhaseView: View {
    let onRecord: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Button(action: onRecord) {
                Image(systemName: "mic.circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(minWidth: 88, minHeight: 88)
                    .foregroundStyle(Color.accentColor)
            }
            .accessibilityLabel("울음 분석 녹음 시작")
            .accessibilityValue("대기 중. 탭하여 녹음 시작")

            Text("버튼을 눌러 아기의 울음 소리를 5초간 녹음하세요")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 24)
    }
}

// MARK: - Permission Required Phase

private struct PermissionRequiredView: View {
    let onRequest: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "mic.slash.circle")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("울음 분석을 위해 마이크 권한이 필요합니다")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("마이크 권한 요청", action: onRequest)
                .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 24)
    }
}

// MARK: - Permission Denied Phase

private struct PermissionDeniedView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "mic.slash.fill")
                .font(.system(size: 48))
                .foregroundStyle(.red)

            Text("마이크 권한이 필요합니다")
                .font(.headline)

            Text("설정에서 마이크 권한을 허용해 주세요")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("설정 열기") {
                UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 24)
    }
}

// MARK: - Recording Phase

private struct RecordingPhaseView: View {
    let progress: Double
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 8)
                    .frame(width: 100, height: 100)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.2), value: progress)

                Image(systemName: "waveform")
                    .font(.system(size: 28))
                    .foregroundStyle(Color.accentColor)
            }

            Text("녹음 중... \(Int(progress * 100))%")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button("취소", action: onCancel)
                .buttonStyle(.bordered)
        }
        .padding(.vertical, 24)
    }
}

// MARK: - Analyzing Phase

private struct AnalyzingPhaseView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)

            Text("분석 중...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 32)
    }
}

// MARK: - Result Phase

private struct ResultPhaseView: View {
    let record: CryRecord
    let onSave: () -> Void
    let onRetry: () -> Void

    private var sortedProbabilities: [(CryLabel, Double)] {
        record.labelProbabilities
            .sorted { $0.value > $1.value }
    }

    var body: some View {
        VStack(spacing: 20) {
            // 확률 바 차트
            if !sortedProbabilities.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("울음 패턴 분석 결과")
                        .font(.headline)

                    Chart(sortedProbabilities, id: \.0) { label, probability in
                        BarMark(
                            x: .value("확률", probability),
                            y: .value("유형", label.localizedDescription)
                        )
                        .foregroundStyle(Color.accentColor.gradient)
                        .annotation(position: .trailing) {
                            Text("\(Int(probability * 100))%")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .chartXScale(domain: 0...1)
                    .chartXAxis(.hidden)
                    .frame(height: CGFloat(sortedProbabilities.count) * 44)
                }
                .padding()
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
            }

            // 상위 라벨 설명 (면책 표현 준수)
            if let top = record.topLabel {
                VStack(spacing: 6) {
                    Text("\(top.localizedDescription) 신호와 유사해요")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                    Text("참고 정보로만 활용하시고 아기의 상태를 직접 확인해 주세요.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal)
            }

            // 저장 / 다시 녹음 버튼
            HStack(spacing: 12) {
                Button("저장", action: onSave)
                    .buttonStyle(.borderedProminent)

                Button("다시 녹음", action: onRetry)
                    .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Error Phase

private struct ErrorPhaseView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.red)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("다시 시도", action: onRetry)
                .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 24)
    }
}

// MARK: - History Section

private struct HistorySection: View {
    let history: [CryRecord]

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        f.locale = Locale(identifier: "ko_KR")
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("최근 분석 기록")
                .font(.headline)
                .padding(.top, 8)

            ForEach(history.prefix(20)) { record in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        if let label = record.topLabel {
                            Text("\(label.localizedDescription) 신호와 유사해요")
                                .font(.subheadline)
                        } else {
                            Text("패턴 미분류")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Text(Self.formatter.string(from: record.recordedAt))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if record.isStub {
                        Text("테스트")
                            .font(.caption2)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary, in: Capsule())
                    }
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
            }
        }
    }
}

// MARK: - Onboarding Sheet

private struct OnboardingSheet: View {
    let onConfirm: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Image(systemName: "ear.badge.waveform")
                            .font(.system(size: 44))
                            .foregroundStyle(Color.accentColor)
                        Spacer()
                    }

                    Text("울음 분석 기능 안내")
                        .font(.title2)
                        .fontWeight(.bold)

                    VStack(alignment: .leading, spacing: 12) {
                        OnboardingRow(
                            icon: "info.circle.fill",
                            color: .orange,
                            title: "참고 정보입니다",
                            description: "본 기능은 의료 진단이 아닙니다. AI 추정이며 정확도가 제한적입니다. 아기의 상태는 반드시 직접 확인하세요."
                        )
                        OnboardingRow(
                            icon: "mic.circle.fill",
                            color: .accentColor,
                            title: "사용 방법",
                            description: "조용한 환경에서 버튼을 눌러 아기의 울음 소리를 5초간 녹음하세요. AI가 울음 패턴을 분석합니다."
                        )
                        OnboardingRow(
                            icon: "chart.bar.fill",
                            color: .purple,
                            title: "결과 해석",
                            description: "결과는 유사한 울음 신호와의 패턴 비교입니다. 하나의 참고 정보로만 활용하세요."
                        )
                    }
                }
                .padding(24)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("확인") {
                        onConfirm()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct OnboardingRow: View {
    let icon: String
    let color: Color
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

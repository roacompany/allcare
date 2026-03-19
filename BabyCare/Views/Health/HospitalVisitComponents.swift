import SwiftUI

// MARK: - Hospital Report Sheet

struct HospitalReportSheet: View {
    let visit: HospitalVisit
    @Bindable var reportVM: HospitalReportViewModel
    let userId: String
    let baby: Baby?
    let previousVisitDate: Date?

    var body: some View {
        Group {
            switch reportVM.state {
            case .idle, .analyzing, .generating:
                HospitalReportLoadingView(state: reportVM.state)
                    .task {
                        guard let baby else {
                            reportVM.state = .failed("아기 정보를 불러올 수 없습니다.")
                            return
                        }
                        guard !userId.isEmpty else {
                            reportVM.state = .failed("로그인 정보를 확인해주세요.")
                            return
                        }
                        await reportVM.generate(
                            baby: baby,
                            visit: visit,
                            previousVisitDate: previousVisitDate,
                            userId: userId
                        )
                    }

            case .done(let report):
                HospitalReportView(
                    report: report,
                    visitName: visit.hospitalName
                )

            case .failed(let message):
                ErrorStateView(message: message) {
                    guard let baby else { return }
                    Task {
                        reportVM.reset()
                        await reportVM.generate(
                            baby: baby,
                            visit: visit,
                            previousVisitDate: previousVisitDate,
                            userId: userId
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Error State View

struct ErrorStateView: View {
    let message: String
    let onRetry: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 52))
                .foregroundStyle(.orange)
            Text("리포트 생성 실패")
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            HStack(spacing: 16) {
                Button("닫기") { dismiss() }
                    .buttonStyle(.bordered)
                Button("다시 시도") { onRetry() }
                    .buttonStyle(.borderedProminent)
            }
            Spacer()
        }
    }
}

// MARK: - Visit Row

struct HospitalVisitRow: View {
    let visit: HospitalVisit

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(hex: visit.visitType.color).opacity(0.2))
                    .frame(width: 40, height: 40)
                Image(systemName: visit.visitType.icon)
                    .font(.body)
                    .foregroundStyle(Color(hex: visit.visitType.color))
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(visit.hospitalName)
                        .font(.subheadline.weight(.medium))
                    Text(visit.visitType.displayName)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color(hex: visit.visitType.color)))
                }

                Text(DateFormatters.dateTime.string(from: visit.visitDate))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let purpose = visit.purpose, !purpose.isEmpty {
                    Text(purpose)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if visit.isUpcoming {
                Text(daysUntilText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.blue)
            }

            if visit.hasNextVisit {
                Image(systemName: "arrow.forward.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 2)
    }

    private var daysUntilText: String {
        let days = Calendar.current.dateComponents([.day], from: Date(), to: visit.visitDate).day ?? 0
        if days == 0 { return "오늘" }
        if days == 1 { return "내일" }
        return "\(days)일 후"
    }
}

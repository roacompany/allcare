import SwiftUI

// MARK: - 병원 방문 AI 리포트 뷰

struct HospitalReportView: View {
    let report: AIReport
    let visitName: String

    @Environment(\.dismiss) private var dismiss
    @State private var checkedItems: Set<String> = []
    @State private var showShareSheet = false
    @State private var shareText = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 헤더
                    headerCard

                    // 요약
                    summaryCard

                    // 주요 변화
                    if !report.keyChanges.isEmpty {
                        keyChangesCard
                    }

                    // 체크리스트
                    if !report.checklistItems.isEmpty {
                        checklistCard
                    }

                    // 면책 고지
                    disclaimerCard
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("AI 리포트")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        prepareShare()
                        showShareSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(text: shareText)
            }
        }
    }

    // MARK: - Cards

    private var headerCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Label(visitName, systemImage: "building.2.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.blue)
                HStack(spacing: 6) {
                    Text("AI 병원 방문 리포트")
                        .font(.title3.weight(.bold))
                    AIGeneratedLabel()
                }
                Text(DateFormatters.shortDate.string(from: report.generatedAt))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 52, height: 52)
                Image(systemName: "brain.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("종합 요약", systemImage: "doc.text.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(report.summary)
                .font(.subheadline)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var keyChangesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("주요 변화", systemImage: "chart.line.uptrend.xyaxis")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                ForEach(Array(report.keyChanges.enumerated()), id: \.offset) { index, change in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(index + 1)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 20, height: 20)
                            .background(Circle().fill(Color(red: 0.8, green: 0.4, blue: 0.0)))
                        Text(change)
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var checklistCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("의사에게 물어볼 것", systemImage: "checklist")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(checkedItems.count)/\(report.checklistItems.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.blue)
            }

            VStack(spacing: 8) {
                ForEach(report.checklistItems) { item in
                    ChecklistItemRow(
                        item: item,
                        isChecked: checkedItems.contains(item.id)
                    ) {
                        toggleCheck(item.id)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var disclaimerCard: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(.secondary)
                .font(.caption)
            Text(AIGuardrailService.disclaimer)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineSpacing(2)
        }
        .padding()
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Actions

    private func toggleCheck(_ id: String) {
        if checkedItems.contains(id) {
            checkedItems.remove(id)
        } else {
            checkedItems.insert(id)
        }
    }

    private func prepareShare() {
        var lines: [String] = []
        lines.append("🏥 병원 방문 AI 리포트 — \(visitName)")
        lines.append("")
        lines.append("📋 종합 요약")
        lines.append(report.summary)

        if !report.keyChanges.isEmpty {
            lines.append("")
            lines.append("📊 주요 변화")
            report.keyChanges.enumerated().forEach { i, c in
                lines.append("\(i + 1). \(c)")
            }
        }

        if !report.checklistItems.isEmpty {
            lines.append("")
            lines.append("✅ 의사에게 물어볼 것")
            report.checklistItems.forEach { item in
                lines.append("• \(item.question)")
            }
        }

        lines.append("")
        lines.append("⚠️ 이 리포트는 AI 참고 자료이며 의사의 진단을 대체하지 않습니다.")
        shareText = lines.joined(separator: "\n")
    }
}

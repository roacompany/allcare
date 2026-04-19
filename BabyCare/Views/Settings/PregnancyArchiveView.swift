import SwiftUI

/// 이전 임신 이력 조회 뷰.
/// outcome별 아이콘/문구 구분. 삭제 불가 (감정적 리스크 + 데이터 영구 손실 방지).
struct PregnancyArchiveView: View {
    @Environment(PregnancyViewModel.self) private var pregnancyVM
    @Environment(AuthViewModel.self) private var authVM

    var body: some View {
        List {
            if pregnancyVM.archivedPregnancies.isEmpty {
                ContentUnavailableView(
                    "이전 임신 이력 없음",
                    systemImage: "heart.text.clipboard",
                    description: Text("아직 기록된 이력이 없습니다.")
                )
            } else {
                ForEach(pregnancyVM.archivedPregnancies) { pregnancy in
                    NavigationLink {
                        PregnancyArchiveDetailView(pregnancy: pregnancy)
                    } label: {
                        archiveRow(pregnancy)
                    }
                }
            }
        }
        .navigationTitle("이전 임신")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if let userId = authVM.currentUserId {
                await pregnancyVM.loadArchivedPregnancies(userId: userId)
            }
        }
    }

    private func archiveRow(_ p: Pregnancy) -> some View {
        HStack(spacing: 12) {
            Image(systemName: outcomeIcon(p.outcome))
                .font(.title3)
                .foregroundStyle(outcomeColor(p.outcome))
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                if let nickname = p.babyNickname, !nickname.isEmpty {
                    Text(nickname)
                        .font(.headline)
                }
                Text(outcomeLabel(p.outcome))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let archived = p.archivedAt {
                    Text(archived, style: .date)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func outcomeIcon(_ outcome: PregnancyOutcome?) -> String {
        switch outcome {
        case .born: return "heart.fill"
        case .miscarriage, .stillbirth: return "leaf.fill"
        case .terminated: return "leaf.fill"
        default: return "questionmark.circle"
        }
    }

    private func outcomeColor(_ outcome: PregnancyOutcome?) -> Color {
        switch outcome {
        case .born: return AppColors.primaryAccent
        case .miscarriage, .stillbirth, .terminated: return .secondary
        default: return .gray
        }
    }

    private func outcomeLabel(_ outcome: PregnancyOutcome?) -> String {
        outcome?.displayName ?? "알 수 없음"
    }
}

/// 이전 임신 상세 (기록 요약).
struct PregnancyArchiveDetailView: View {
    let pregnancy: Pregnancy

    var body: some View {
        List {
            Section("기본 정보") {
                if let nickname = pregnancy.babyNickname {
                    LabeledContent("태명", value: nickname)
                }
                if let due = pregnancy.dueDate {
                    LabeledContent("예정일") {
                        Text(due, style: .date)
                    }
                }
                if let outcome = pregnancy.outcome {
                    LabeledContent("결과", value: outcome.displayName)
                }
                if let archived = pregnancy.archivedAt {
                    LabeledContent("종료일") {
                        Text(archived, style: .date)
                    }
                }
                if let count = pregnancy.fetusCount, count > 1 {
                    LabeledContent("태아 수", value: "\(count)")
                }
            }

            if let weeks = pregnancy.currentWeekAndDay {
                Section("진행 기록") {
                    LabeledContent("최종 주차", value: "\(weeks.weeks)주 \(weeks.days)일")
                }
            }
        }
        .navigationTitle(pregnancy.babyNickname ?? "이전 임신")
        .navigationBarTitleDisplayMode(.inline)
    }
}

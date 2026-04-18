import SwiftUI

struct PregnancyRegistrationView: View {
    @Environment(PregnancyViewModel.self) private var pregnancyVM
    @Environment(AuthViewModel.self) private var authVM
    @Environment(\.dismiss) private var dismiss

    @State private var lmpDate: Date = Calendar.current.date(byAdding: .day, value: -84, to: Date()) ?? Date()
    @State private var eddDate: Date = Calendar.current.date(byAdding: .day, value: 196, to: Date()) ?? Date()
    @State private var fetusCount: Int = 1
    @State private var babyNickname: String = ""
    @State private var gender: UltrasoundGender = .unknown
    @State private var lmpIsSource = true // LMP가 마지막으로 편집된 소스인지 추적

    private static let dayInterval: Int = 280

    /// LMP 허용 범위: 오늘로부터 -310일(약 44주, 만삭+α) ~ 오늘
    private var lmpRange: ClosedRange<Date> {
        let cal = Calendar.current
        let lower = cal.date(byAdding: .day, value: -310, to: Date()) ?? Date.distantPast
        return lower...Date()
    }

    /// EDD 허용 범위: 오늘 ~ 오늘 + 310일 (약 44주)
    private var eddRange: ClosedRange<Date> {
        let cal = Calendar.current
        let upper = cal.date(byAdding: .day, value: 310, to: Date()) ?? Date.distantFuture
        return Date()...upper
    }

    var body: some View {
        NavigationStack {
            Form {
                // 면책 배너
                Section {
                    PregnancyDisclaimerBanner(
                        text: "이 정보는 일반적인 참고 자료이며 의학적 진단을 대체하지 않습니다."
                    )
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

                if fetusCount > 1 {
                    Section {
                        PregnancyDisclaimerBanner(
                            text: "단태아 기준 정보입니다. 다태임신은 담당 의료진과 상의하세요.",
                            color: .purple
                        )
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                Section("임신 날짜") {
                    DatePicker(
                        "마지막 월경일 (LMP)",
                        selection: $lmpDate,
                        in: lmpRange,
                        displayedComponents: .date
                    )
                    .environment(\.locale, Locale(identifier: "ko_KR"))
                    .onChange(of: lmpDate) { _, newLMP in
                        lmpIsSource = true
                        eddDate = Calendar.current.date(byAdding: .day, value: Self.dayInterval, to: newLMP) ?? eddDate
                    }

                    DatePicker(
                        "예정일 (EDD)",
                        selection: $eddDate,
                        in: eddRange,
                        displayedComponents: .date
                    )
                    .environment(\.locale, Locale(identifier: "ko_KR"))
                    .onChange(of: eddDate) { _, newEDD in
                        lmpIsSource = false
                        lmpDate = Calendar.current.date(byAdding: .day, value: -Self.dayInterval, to: newEDD) ?? lmpDate
                    }
                }

                Section("임신 정보") {
                    Picker("태아 수", selection: $fetusCount) {
                        Text("단태아 (1명)").tag(1)
                        Text("쌍태아 (2명)").tag(2)
                        Text("세쌍둥이 (3명)").tag(3)
                    }

                    TextField("태명 (선택)", text: $babyNickname)
                }

                Section("초음파 성별") {
                    Picker("초음파 성별", selection: $gender) {
                        ForEach(UltrasoundGender.allCases, id: \.self) { g in
                            Text(g.displayName).tag(g)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if let error = pregnancyVM.errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("임신 등록")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        Task {
                            guard let userId = authVM.currentUserId else { return }
                            let nickname = babyNickname.trimmingCharacters(in: .whitespaces)
                            await pregnancyVM.createPregnancy(
                                lmpDate: lmpDate,
                                dueDate: eddDate,
                                fetusCount: fetusCount,
                                babyNickname: nickname.isEmpty ? nil : nickname,
                                userId: userId
                            )
                            if pregnancyVM.errorMessage == nil {
                                dismiss()
                            }
                        }
                    }
                    .disabled(pregnancyVM.isLoading)
                }
            }
        }
    }
}

// MARK: - Ultrasound Gender

enum UltrasoundGender: String, CaseIterable, Codable {
    case unknown = "미확인"
    case boy = "남아"
    case girl = "여아"

    var displayName: String { rawValue }
}

// MARK: - Disclaimer Banner

private struct PregnancyDisclaimerBanner: View {
    let text: String
    var color: Color = .orange

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(color)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(Color.primary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(color.opacity(0.4), lineWidth: 1)
        )
    }
}

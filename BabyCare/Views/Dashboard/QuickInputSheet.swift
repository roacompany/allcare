import SwiftUI

struct QuickInputSheet: View {
    let type: Activity.ActivityType
    let onSave: (Activity) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(BabyViewModel.self) private var babyVM
    @Environment(ActivityViewModel.self) private var activityVM

    // 시간 조정
    @State private var recordTime = Date()
    @State private var isTimeExpanded = false

    // 체온
    @State private var temperature = "36.5"

    // 투약
    @State private var medicationName = ""
    @State private var medicationDosage = ""

    // 분유 / 유축량
    @State private var amount = ""

    // 병수유 내용물 (분유/모유)
    @State private var selectedFeedingContent: Activity.FeedingContent = .formula

    // 유축 방향 (좌/우/양쪽)
    @State private var selectedSide: Activity.BreastSide = .both

    // 메모
    @State private var note = ""

    private var canSave: Bool {
        switch type {
        case .temperature:
            return Double(temperature) != nil
        case .medication:
            return !medicationName.trimmingCharacters(in: .whitespaces).isEmpty
        case .feedingBottle, .feedingPumping:
            return Double(amount) != nil && (Double(amount) ?? 0) > 0
        case .unknown:
            return false   // forward-compat 센티넬은 저장 불가 (진입 불가하나 default:true 트랩 방어)
        default:
            return true
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 타입 헤더
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color(type.color).opacity(0.2))
                            .frame(width: 48, height: 48)
                        Image(systemName: type.icon)
                            .font(.title3)
                            .foregroundStyle(Color(type.color))
                    }
                    Text(type.displayName)
                        .font(.title3.weight(.semibold))
                    Spacer()
                }
                .padding()

                Divider()

                // 입력 필드
                Form {
                    // 시간 조정 섹션
                    Section {
                        Button {
                            withAnimation(.spring(duration: 0.3)) {
                                isTimeExpanded.toggle()
                            }
                        } label: {
                            HStack {
                                Image(systemName: "clock.fill")
                                    .foregroundStyle(Color(type.color))
                                Text("기록 시간")
                                Spacer()
                                Text(timeLabel(recordTime))
                                    .foregroundStyle(isTimeAdjusted ? Color(type.color) : .secondary)
                                Image(systemName: isTimeExpanded ? "chevron.up" : "chevron.down")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .foregroundStyle(.primary)

                        if isTimeExpanded {
                            DatePicker(
                                "시간 선택",
                                selection: $recordTime,
                                in: ...Date(),
                                displayedComponents: [.date, .hourAndMinute]
                            )
                            .datePickerStyle(.compact)
                            .environment(\.locale, Locale(identifier: "ko_KR"))

                            HStack(spacing: 8) {
                                ForEach(["지금", "5분 전", "15분 전", "30분 전"], id: \.self) { label in
                                    Button(label) {
                                        recordTime = quickTime(label)
                                    }
                                    .font(.system(size: 13, weight: .medium))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(Color(type.color).opacity(0.12))
                                    .foregroundStyle(Color(type.color))
                                    .clipShape(Capsule())
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    switch type {
                    case .temperature:
                        temperatureInput
                    case .medication:
                        medicationInput
                    case .feedingBottle:
                        bottleInput
                    case .feedingPumping:
                        pumpInput
                    default:
                        EmptyView()
                    }

                    Section("메모 (선택)") {
                        TextField("추가 내용을 입력하세요", text: $note, axis: .vertical)
                            .lineLimit(3, reservesSpace: false)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        save()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSave)
                }
            }
            .onAppear {
                // B3: 직전 값 프리필 (분유/유축량 + 병수유 내용물) — 빈 값일 때만
                if (type == .feedingBottle || type == .feedingPumping), amount.isEmpty,
                   let last = RecordPrefillPolicy.lastAmount(
                       type: type,
                       todayActivities: activityVM.todayActivities,
                       recentActivities: activityVM.recentWeekActivities
                   ) {
                    amount = last
                }
                if type == .feedingBottle,
                   let content = RecordPrefillPolicy.lastFeedingContent(
                       todayActivities: activityVM.todayActivities,
                       recentActivities: activityVM.recentWeekActivities
                   ) {
                    selectedFeedingContent = content
                }
            }
        }
    }

    // MARK: - Temperature Input

    private var temperatureInput: some View {
        Section {
            HStack {
                Text("체온")
                Spacer()
                TextField("36.5", text: $temperature)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                Text("°C")
                    .foregroundStyle(.secondary)
            }

            if let temp = Double(temperature) {
                HStack {
                    Text("상태")
                    Spacer()
                    Text(temperatureStatus(temp))
                        .foregroundStyle(temperatureStatusColor(temp))
                        .fontWeight(.medium)
                }
            }
        } footer: {
            Text("정상 범위: 36.0~37.5°C / 37.5°C 이상 발열 / 38.0°C 이상 고열")
        }
    }

    // MARK: - Medication Input

    private var medicationInput: some View {
        Group {
            Section("약 정보") {
                TextField("약 이름", text: $medicationName)
                TextField("용량 (선택)", text: $medicationDosage)
            }

            if !RecentMedications.list.isEmpty {
                Section("최근 투약") {
                    ForEach(RecentMedications.list, id: \.self) { name in
                        Button {
                            medicationName = name
                        } label: {
                            HStack {
                                Image(systemName: "clock")
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                                Text(name)
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Bottle Input

    private var bottleInput: some View {
        Section {
            Picker("내용물", selection: $selectedFeedingContent) {
                Text("분유").tag(Activity.FeedingContent.formula)
                Text("유축한 모유").tag(Activity.FeedingContent.breastMilk)
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("병수유 내용물")

            HStack {
                Text("수유량")
                Spacer()
                TextField("0", text: $amount)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                Text("ml")
                    .foregroundStyle(.secondary)
            }
        } footer: {
            Text("일반적인 1회 수유량: 신생아 60~90ml, 3개월 120~150ml, 6개월 180~240ml")
        }
    }

    // MARK: - Pump Input

    private var pumpInput: some View {
        Section {
            HStack {
                Text("유축량")
                Spacer()
                TextField("0", text: $amount)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                Text("ml")
                    .foregroundStyle(.secondary)
            }

            Picker("방향", selection: $selectedSide) {
                ForEach(Activity.BreastSide.allCases, id: \.self) { side in
                    Text(side.displayName).tag(side)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("유축 방향")
        } footer: {
            // 온보딩 카피 (spec §9) — 완전유축 사용자가 섭취총량 혼란을 겪지 않도록 안내
            Text("유축 기록은 ‘짜낸 양’이에요. 아기가 실제로 먹은 양은 분유/모유 수유로 따로 기록해 주세요. 그래야 섭취량 통계와 병원 리포트가 정확해요.")
        }
    }

    // MARK: - Save

    /// QuickInput 폼 값 묶음 — buildActivity 파라미터 수 제한(lint) + 폼 확장 시 시그니처 안정.
    struct Values {
        var amount = ""
        var side: Activity.BreastSide?
        var feedingContent: Activity.FeedingContent = .formula
        var temperature = ""
        var medicationName = ""
        var medicationDosage = ""
        var note = ""
    }

    /// 저장 활동 구성 — 순수 함수로 분리하여 단위 테스트 가능 (side 플러밍 가드, spec §7-2).
    /// nonisolated: View(@MainActor)에 속하지만 순수 값 변환이라 actor 격리 불필요 (테스트 MainActor 호핑 회피).
    nonisolated static func buildActivity(
        babyId: String,
        type: Activity.ActivityType,
        recordTime: Date,
        values: Values
    ) -> Activity {
        var activity = Activity(babyId: babyId, type: type)
        activity.startTime = recordTime

        switch type {
        case .temperature:
            activity.temperature = Double(values.temperature)
        case .medication:
            activity.medicationName = values.medicationName.trimmingCharacters(in: .whitespaces)
            activity.medicationDosage = values.medicationDosage.isEmpty ? nil : values.medicationDosage
        case .feedingBottle:
            activity.amount = Double(values.amount)
            activity.feedingContent = values.feedingContent
        case .feedingPumping:
            activity.amount = Double(values.amount)
            activity.side = values.side
        default:
            break
        }

        let trimmedNote = values.note.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedNote.isEmpty {
            activity.note = trimmedNote
        }
        return activity
    }

    private func save() {
        guard let babyId = babyVM.selectedBaby?.id else { return }

        let activity = Self.buildActivity(
            babyId: babyId,
            type: type,
            recordTime: recordTime,
            values: .init(
                amount: amount,
                side: type == .feedingPumping ? selectedSide : nil,
                feedingContent: selectedFeedingContent,
                temperature: temperature,
                medicationName: medicationName,
                medicationDosage: medicationDosage,
                note: note
            )
        )

        if type == .medication {
            RecentMedications.add(activity.medicationName ?? "")
        }

        onSave(activity)
    }

    private var isTimeAdjusted: Bool {
        abs(recordTime.timeIntervalSinceNow) > 60
    }

    private func timeLabel(_ date: Date) -> String {
        let f = DateFormatter()
        if Calendar.current.isDateInToday(date) {
            f.dateFormat = "a h:mm"
        } else {
            f.dateFormat = "M/d a h:mm"
        }
        f.locale = Locale(identifier: "ko_KR")
        return f.string(from: date)
    }

    private func quickTime(_ label: String) -> Date {
        switch label {
        case "5분 전":  return Date().addingTimeInterval(-5 * 60)
        case "15분 전": return Date().addingTimeInterval(-15 * 60)
        case "30분 전": return Date().addingTimeInterval(-30 * 60)
        default:       return Date()
        }
    }

    // MARK: - Helpers

    private func temperatureStatus(_ temp: Double) -> String {
        if temp < 35.0 { return "저체온" }
        if temp <= 37.5 { return "정상" }
        if temp <= 38.0 { return "미열" }
        if temp <= 39.0 { return "발열" }
        return "고열"
    }

    private func temperatureStatusColor(_ temp: Double) -> Color {
        if temp < 35.0 { return .blue }
        if temp <= 37.5 { return AppColors.successColor }
        if temp <= 38.0 { return .orange }
        return .red
    }
}

// MARK: - Recent Medications (UserDefaults)

enum RecentMedications {
    private static let key = "recentMedications"
    private static let maxCount = 5

    static var list: [String] {
        UserDefaults.standard.stringArray(forKey: key) ?? []
    }

    static func add(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var meds = list.filter { $0 != trimmed }
        meds.insert(trimmed, at: 0)
        if meds.count > maxCount {
            meds = Array(meds.prefix(maxCount))
        }
        UserDefaults.standard.set(meds, forKey: key)
    }
}

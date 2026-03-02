import SwiftUI

struct SettingsView: View {
    @Environment(AuthViewModel.self) private var authVM
    @Environment(BabyViewModel.self) private var babyVM

    @State private var showAddBaby = false
    @State private var showLogoutAlert = false

    var body: some View {
        NavigationStack {
            List {
                // Baby Management Section
                Section("아기 관리") {
                    ForEach(babyVM.babies) { baby in
                        NavigationLink {
                            BabyDetailView(baby: baby)
                        } label: {
                            HStack(spacing: 12) {
                                Text(baby.gender.emoji)
                                    .font(.title2)
                                VStack(alignment: .leading) {
                                    Text(baby.name)
                                        .font(.body.weight(.medium))
                                    Text(baby.ageText)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

                    Button {
                        showAddBaby = true
                    } label: {
                        Label("아기 추가", systemImage: "plus.circle.fill")
                    }
                }

                // Features Section
                Section("기능") {
                    NavigationLink {
                        ProductListView()
                    } label: {
                        Label("용품 관리", systemImage: "bag.fill")
                    }

                    NavigationLink {
                        TodoView()
                    } label: {
                        Label("할 일", systemImage: "checklist")
                    }

                    NavigationLink {
                        GrowthView()
                    } label: {
                        Label("성장 기록", systemImage: "chart.line.uptrend.xyaxis")
                    }

                    NavigationLink {
                        DiaryView()
                    } label: {
                        Label("일기", systemImage: "book.fill")
                    }
                }

                // App Section
                Section("앱 설정") {
                    NavigationLink {
                        Text("알림 설정")
                    } label: {
                        Label("알림 설정", systemImage: "bell.fill")
                    }

                    NavigationLink {
                        Text("테마 설정")
                    } label: {
                        Label("테마", systemImage: "paintpalette.fill")
                    }
                }

                // Account Section
                Section("계정") {
                    if let email = authVM.currentUserId {
                        HStack {
                            Text("로그인")
                            Spacer()
                            Text(email)
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                    }

                    Button(role: .destructive) {
                        showLogoutAlert = true
                    } label: {
                        Label("로그아웃", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }

                // About Section
                Section("정보") {
                    HStack {
                        Text("버전")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("더보기")
            .sheet(isPresented: $showAddBaby) {
                AddBabyView()
            }
            .alert("로그아웃", isPresented: $showLogoutAlert) {
                Button("취소", role: .cancel) {}
                Button("로그아웃", role: .destructive) {
                    authVM.signOut()
                }
            } message: {
                Text("정말 로그아웃 하시겠습니까?")
            }
        }
    }
}

// MARK: - Baby Detail View

struct BabyDetailView: View {
    let baby: Baby
    @Environment(BabyViewModel.self) private var babyVM
    @Environment(AuthViewModel.self) private var authVM

    @State private var name: String
    @State private var birthDate: Date
    @State private var gender: Baby.Gender
    @State private var bloodType: Baby.BloodType?
    @State private var showDeleteAlert = false
    @State private var isSaving = false

    init(baby: Baby) {
        self.baby = baby
        _name = State(initialValue: baby.name)
        _birthDate = State(initialValue: baby.birthDate)
        _gender = State(initialValue: baby.gender)
        _bloodType = State(initialValue: baby.bloodType)
    }

    var body: some View {
        Form {
            Section("기본 정보") {
                TextField("이름", text: $name)

                DatePicker("생년월일", selection: $birthDate, displayedComponents: .date)
                    .environment(\.locale, Locale(identifier: "ko_KR"))

                Picker("성별", selection: $gender) {
                    ForEach(Baby.Gender.allCases, id: \.self) { g in
                        Text(g.displayName).tag(g)
                    }
                }

                Picker("혈액형", selection: $bloodType) {
                    Text("미선택").tag(Baby.BloodType?.none)
                    ForEach(Baby.BloodType.allCases, id: \.self) { bt in
                        Text(bt.rawValue).tag(Baby.BloodType?.some(bt))
                    }
                }
            }

            Section("정보") {
                HStack {
                    Text("나이")
                    Spacer()
                    Text(baby.ageText).foregroundStyle(.secondary)
                }
                HStack {
                    Text("태어난 지")
                    Spacer()
                    Text("\(baby.daysOld)일").foregroundStyle(.secondary)
                }
            }

            Section {
                Button("저장") {
                    Task {
                        isSaving = true
                        var updated = baby
                        updated.name = name
                        updated.birthDate = birthDate
                        updated.gender = gender
                        updated.bloodType = bloodType
                        if let userId = authVM.currentUserId {
                            await babyVM.updateBaby(updated, userId: userId)
                        }
                        isSaving = false
                    }
                }
                .disabled(isSaving)
            }

            Section {
                Button("아기 삭제", role: .destructive) {
                    showDeleteAlert = true
                }
            }
        }
        .navigationTitle(baby.name)
        .alert("아기 삭제", isPresented: $showDeleteAlert) {
            Button("취소", role: .cancel) {}
            Button("삭제", role: .destructive) {
                Task {
                    if let userId = authVM.currentUserId {
                        await babyVM.deleteBaby(baby, userId: userId)
                    }
                }
            }
        } message: {
            Text("'\(baby.name)'의 모든 기록이 삭제됩니다. 되돌릴 수 없습니다.")
        }
    }
}

// MARK: - Add Baby View

struct AddBabyView: View {
    @Environment(BabyViewModel.self) private var babyVM
    @Environment(AuthViewModel.self) private var authVM
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var birthDate = Date()
    @State private var gender: Baby.Gender = .male
    @State private var bloodType: Baby.BloodType?

    var body: some View {
        NavigationStack {
            Form {
                Section("아기 정보") {
                    TextField("이름", text: $name)

                    DatePicker("생년월일", selection: $birthDate, displayedComponents: .date)
                        .environment(\.locale, Locale(identifier: "ko_KR"))

                    Picker("성별", selection: $gender) {
                        ForEach(Baby.Gender.allCases, id: \.self) { g in
                            Text(g.displayName).tag(g)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker("혈액형 (선택)", selection: $bloodType) {
                        Text("미선택").tag(Baby.BloodType?.none)
                        ForEach(Baby.BloodType.allCases, id: \.self) { bt in
                            Text(bt.rawValue).tag(Baby.BloodType?.some(bt))
                        }
                    }
                }
            }
            .navigationTitle("아기 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("추가") {
                        Task {
                            babyVM.babyName = name
                            babyVM.babyBirthDate = birthDate
                            babyVM.babyGender = gender
                            babyVM.babyBloodType = bloodType
                            if let userId = authVM.currentUserId {
                                await babyVM.addBaby(userId: userId)
                            }
                            dismiss()
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

import SwiftUI

struct DiaryView: View {
    @Environment(DiaryViewModel.self) private var diaryVM
    @Environment(BabyViewModel.self) private var babyVM
    @Environment(AuthViewModel.self) private var authVM

    var body: some View {
        NavigationStack {
            Group {
                if diaryVM.entries.isEmpty && !diaryVM.isLoading {
                    EmptyStateView(
                        icon: "book.fill",
                        title: "일기 없음",
                        message: "아기의 하루를 기록해보세요",
                        actionTitle: "일기 쓰기"
                    ) {
                        diaryVM.showAddEntry = true
                    }
                } else {
                    List(diaryVM.entries) { entry in
                        DiaryRowView(entry: entry)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("일기")
            .toolbar {
                Button {
                    diaryVM.showAddEntry = true
                } label: {
                    Image(systemName: "plus")
                }
            }
            .sheet(isPresented: Bindable(diaryVM).showAddEntry) {
                AddDiaryView()
            }
            .task {
                guard let userId = authVM.currentUserId,
                      let babyId = babyVM.selectedBaby?.id else { return }
                await diaryVM.loadEntries(userId: userId, babyId: babyId)
            }
        }
    }
}

// MARK: - Diary Row

struct DiaryRowView: View {
    let entry: DiaryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(DateFormatters.fullDate.string(from: entry.date))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if let mood = entry.mood {
                    Text(mood.emoji)
                        .font(.title3)
                }
            }

            Text(entry.content)
                .font(.body)
                .lineLimit(3)

            if !entry.photoURLs.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "photo.fill")
                        .font(.caption2)
                    Text("\(entry.photoURLs.count)장")
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Add Diary View

struct AddDiaryView: View {
    @Environment(DiaryViewModel.self) private var diaryVM
    @Environment(BabyViewModel.self) private var babyVM
    @Environment(AuthViewModel.self) private var authVM
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var vm = diaryVM

        NavigationStack {
            Form {
                Section("날짜") {
                    DatePicker("날짜", selection: $vm.entryDate, displayedComponents: .date)
                        .environment(\.locale, Locale(identifier: "ko_KR"))
                }

                Section("기분") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(DiaryEntry.Mood.allCases, id: \.self) { mood in
                                Button {
                                    diaryVM.selectedMood = mood
                                } label: {
                                    VStack(spacing: 4) {
                                        Text(mood.emoji)
                                            .font(.largeTitle)
                                        Text(mood.displayName)
                                            .font(.caption2)
                                    }
                                    .padding(8)
                                    .background(
                                        diaryVM.selectedMood == mood
                                            ? Color.accentColor.opacity(0.15)
                                            : Color.clear
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                Section("내용") {
                    TextEditor(text: $vm.content)
                        .frame(minHeight: 150)
                }
            }
            .navigationTitle("일기 쓰기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        diaryVM.resetForm()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        Task {
                            guard let userId = authVM.currentUserId,
                                  let babyId = babyVM.selectedBaby?.id else { return }
                            await diaryVM.addEntry(userId: userId, babyId: babyId)
                            dismiss()
                        }
                    }
                    .disabled(diaryVM.content.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

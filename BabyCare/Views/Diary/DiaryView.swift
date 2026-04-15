import SwiftUI
import PhotosUI

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
                        title: NSLocalizedString("diary.empty.title", comment: ""),
                        message: NSLocalizedString("diary.empty.message", comment: ""),
                        actionTitle: NSLocalizedString("diary.empty.action", comment: "")
                    ) {
                        diaryVM.showAddEntry = true
                    }
                } else {
                    List {
                        // Throwback cards (N개월 전 오늘 회고)
                        let throwbacks = diaryVM.throwbackEntries
                        if !throwbacks.isEmpty {
                            Section {
                                ForEach(throwbacks) { throwback in
                                    DiaryThrowbackCard(throwback: throwback)
                                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                        .listRowSeparator(.hidden)
                                        .listRowBackground(Color.clear)
                                }
                            } header: {
                                Text(NSLocalizedString("diary.throwback.section", comment: ""))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        // Monthly summary card
                        let summary = diaryVM.currentMonthSummary
                        if summary.totalEntries > 0 {
                            Section {
                                DiaryMonthlySummaryCard(summary: summary)
                                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(Color.clear)
                            }
                        }

                        // Mood trend chart
                        let trends = diaryVM.moodTrends
                        if !trends.isEmpty {
                            Section {
                                DiaryMoodTrendChart(trends: trends)
                                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(Color.clear)
                            }
                        }

                        // Diary entries
                        Section {
                            ForEach(diaryVM.entries) { entry in
                                DiaryRowView(entry: entry)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        diaryVM.startEditing(entry)
                                        diaryVM.showAddEntry = true
                                    }
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            Task {
                                                guard let userId = babyVM.resolvedUserId(auth: authVM),
                                                      let babyId = babyVM.selectedBaby?.id else { return }
                                                await diaryVM.deleteEntry(entry, userId: userId, babyId: babyId)
                                            }
                                        } label: {
                                            Label(NSLocalizedString("diary.action.delete", comment: ""), systemImage: "trash")
                                        }
                                    }
                                    .onAppear {
                                        if entry.id == diaryVM.entries.last?.id {
                                            Task {
                                                guard let userId = babyVM.resolvedUserId(auth: authVM),
                                                      let babyId = babyVM.selectedBaby?.id else { return }
                                                await diaryVM.loadMoreEntries(userId: userId, babyId: babyId)
                                            }
                                        }
                                    }
                            }

                            if diaryVM.isLoadingMore {
                                HStack {
                                    Spacer()
                                    ProgressView()
                                        .padding(.vertical, 12)
                                    Spacer()
                                }
                                .listRowSeparator(.hidden)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle(NSLocalizedString("diary.nav.title", comment: ""))
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    // Gallery toggle
                    NavigationLink {
                        DiaryGalleryView()
                    } label: {
                        Image(systemName: "photo.stack")
                    }

                    Button {
                        diaryVM.showAddEntry = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: Bindable(diaryVM).showAddEntry) {
                AddDiaryView()
            }
            .task {
                guard let userId = babyVM.resolvedUserId(auth: authVM),
                      let babyId = babyVM.selectedBaby?.id else { return }
                await diaryVM.loadEntries(userId: userId, babyId: babyId)
            }
            .onChange(of: babyVM.selectedBaby?.id) {
                Task {
                    guard let userId = babyVM.resolvedUserId(auth: authVM),
                          let babyId = babyVM.selectedBaby?.id else { return }
                    await diaryVM.loadEntries(userId: userId, babyId: babyId)
                }
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
                HStack(spacing: 6) {
                    if let firstURL = entry.photoURLs.first {
                        CachedAsyncImage(
                            url: firstURL,
                            size: CGSize(width: 32, height: 32)
                        ) {
                            Image(systemName: "photo.fill")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .frame(width: 32, height: 32)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    HStack(spacing: 4) {
                        Image(systemName: "photo.fill")
                            .font(.caption2)
                        Text("\(entry.photoURLs.count)장")
                            .font(.caption2)
                    }
                    .foregroundStyle(.secondary)
                }
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

    @State private var selectedPhotoItems: [PhotosPickerItem] = []

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

                Section("사진") {
                    // Existing photos (edit mode)
                    if !diaryVM.existingPhotoURLs.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(diaryVM.existingPhotoURLs, id: \.self) { urlString in
                                    ZStack(alignment: .topTrailing) {
                                        CachedAsyncImage(
                                            url: urlString,
                                            size: CGSize(width: 80, height: 80)
                                        ) {
                                            Color.secondary.opacity(0.2)
                                                .frame(width: 80, height: 80)
                                        }
                                        .frame(width: 80, height: 80)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))

                                        Button {
                                            diaryVM.existingPhotoURLs.removeAll { $0 == urlString }
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.title3)
                                                .foregroundStyle(.white, .black.opacity(0.6))
                                        }
                                        .buttonStyle(.plain)
                                        .offset(x: 4, y: -4)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    // New photos to add
                    if !diaryVM.selectedPhotos.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Array(diaryVM.selectedPhotos.enumerated()), id: \.offset) { index, photo in
                                    ZStack(alignment: .topTrailing) {
                                        Image(uiImage: photo)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 80, height: 80)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))

                                        Button {
                                            diaryVM.selectedPhotos.remove(at: index)
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.title3)
                                                .foregroundStyle(.white, .black.opacity(0.6))
                                        }
                                        .buttonStyle(.plain)
                                        .offset(x: 4, y: -4)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    PhotosPicker(
                        selection: $selectedPhotoItems,
                        maxSelectionCount: 5,
                        matching: .images
                    ) {
                        Label("사진 추가", systemImage: "photo.badge.plus")
                    }
                    .onChange(of: selectedPhotoItems) { _, newItems in
                        Task {
                            var images: [UIImage] = []
                            for item in newItems {
                                if let data = try? await item.loadTransferable(type: Data.self),
                                   let image = UIImage(data: data) {
                                    images.append(image)
                                }
                            }
                            diaryVM.selectedPhotos = images
                            selectedPhotoItems = []
                        }
                    }
                }
            }
            .navigationTitle(diaryVM.editingEntry != nil ? "일기 수정" : "일기 쓰기")
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
                            guard let userId = babyVM.resolvedUserId(auth: authVM),
                                  let babyId = babyVM.selectedBaby?.id else { return }
                            await diaryVM.addEntry(userId: userId, babyId: babyId)
                            if diaryVM.errorMessage == nil {
                                dismiss()
                            }
                        }
                    }
                    .disabled(diaryVM.content.trimmingCharacters(in: .whitespaces).isEmpty || diaryVM.isLoading)
                }
            }
        }
    }
}

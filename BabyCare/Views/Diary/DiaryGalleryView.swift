import SwiftUI

// MARK: - Diary Gallery View

struct DiaryGalleryView: View {
    @Environment(DiaryViewModel.self) private var diaryVM
    @Environment(BabyViewModel.self) private var babyVM
    @Environment(AuthViewModel.self) private var authVM

    @State private var selectedEntry: DiaryEntry?

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]

    var body: some View {
        let items = diaryVM.photoItems

        Group {
            if items.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text(NSLocalizedString("diary.gallery.empty", comment: ""))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 2) {
                        ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                            GalleryCell(urlString: item.url)
                                .aspectRatio(1, contentMode: .fill)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedEntry = item.entry
                                }
                        }
                    }
                }
            }
        }
        .navigationTitle(NSLocalizedString("diary.gallery.title", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedEntry) { entry in
            DiaryEntryDetailSheet(entry: entry)
        }
    }
}

// MARK: - Gallery Cell

private struct GalleryCell: View {
    let urlString: String

    var body: some View {
        GeometryReader { geo in
            CachedAsyncImage(
                url: urlString,
                size: CGSize(width: geo.size.width, height: geo.size.height)
            ) {
                Color.secondary.opacity(0.2)
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
    }
}

// MARK: - Diary Entry Detail Sheet

private struct DiaryEntryDetailSheet: View {
    @Environment(DiaryViewModel.self) private var diaryVM
    let entry: DiaryEntry
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Date & Mood
                    HStack {
                        Text(DateFormatters.fullDate.string(from: entry.date))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        if let mood = entry.mood {
                            Text(mood.emoji + " " + mood.displayName)
                                .font(.subheadline)
                        }
                    }
                    .padding(.horizontal)

                    // Photos
                    if !entry.photoURLs.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(entry.photoURLs, id: \.self) { urlString in
                                    CachedAsyncImage(
                                        url: urlString,
                                        size: CGSize(width: 200, height: 200)
                                    ) {
                                        Color.secondary.opacity(0.2)
                                            .frame(width: 200, height: 200)
                                    }
                                    .frame(width: 200, height: 200)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }
                            .padding(.horizontal)
                        }
                    }

                    // Content
                    Text(entry.content)
                        .font(.body)
                        .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle(NSLocalizedString("diary.gallery.detail.title", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("diary.gallery.detail.close", comment: "")) {
                        dismiss()
                    }
                }
            }
        }
    }
}

import SwiftUI

struct BadgeGalleryView: View {
    @Environment(AuthViewModel.self) private var authVM

    @State private var vm = BadgeViewModel()
    @State private var selected: BadgeCatalog.Definition?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    var body: some View {
        ScrollView {
            if !vm.isLoaded {
                ProgressView()
                    .padding(40)
            } else {
                LazyVStack(alignment: .leading, spacing: 20, pinnedViews: []) {
                    section(title: LocalizedStringKey("badge.section.firstTime"), category: .firstTime)
                    section(title: LocalizedStringKey("badge.section.aggregate"), category: .aggregate)
                    section(title: LocalizedStringKey("badge.section.streak"), category: .streak)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
        }
        .background(AppColors.background)
        .navigationTitle(LocalizedStringKey("badge.gallery.title"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selected) { def in
            BadgeDetailSheet(definition: def, earned: vm.earnedBadge(for: def), stats: vm.stats)
        }
        .task {
            if let uid = authVM.currentUserId {
                await vm.load(userId: uid)
            }
        }
    }

    @ViewBuilder
    private func section(title: LocalizedStringKey, category: BadgeCategory) -> some View {
        let defs = BadgeCatalog.all.filter { $0.category == category }
        if !defs.isEmpty {
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(defs, id: \.id) { def in
                    Button {
                        selected = def
                    } label: {
                        BadgeTileView(
                            definition: def,
                            earned: vm.earnedBadge(for: def),
                            stats: vm.stats
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

extension BadgeCatalog.Definition: Identifiable {}

// MARK: - Tile

struct BadgeTileView: View {
    let definition: BadgeCatalog.Definition
    let earned: Badge?
    let stats: UserStats?

    var isEarned: Bool { earned != nil }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(AppColors.cardBackground)
                VStack(spacing: 4) {
                    Image(systemName: definition.iconSFSymbol)
                        .font(.system(size: 30))
                        .foregroundStyle(isEarned ? AppColors.primaryAccent : Color.secondary)
                    Text(LocalizedStringKey(definition.titleKey))
                        .font(.caption2.weight(.medium))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .foregroundStyle(.primary)
                }
                .padding(8)
                if !isEarned {
                    Image(systemName: "lock.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(6)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .saturation(isEarned ? 1.0 : 0.1)
            .opacity(isEarned ? 1.0 : 0.7)

            if !isEarned, definition.category == .aggregate {
                ProgressView(value: BadgeTileView.progress(definition: definition, stats: stats))
                    .progressViewStyle(.linear)
                    .tint(AppColors.primaryAccent)
                    .frame(height: 4)
            }
        }
    }

    static func progress(definition: BadgeCatalog.Definition, stats: UserStats?) -> Double {
        guard let field = definition.statsField, definition.threshold > 0 else { return 0 }
        let current = fieldValue(field: field, stats: stats)
        let raw = Double(current) / Double(definition.threshold)
        return min(max(raw, 0), 1)
    }

    static func fieldValue(field: String, stats: UserStats?) -> Int {
        guard let s = stats else { return 0 }
        switch field {
        case "feedingCount":      return s.feedingCount ?? 0
        case "sleepCount":        return s.sleepCount ?? 0
        case "diaperCount":       return s.diaperCount ?? 0
        case "growthRecordCount": return s.growthRecordCount ?? 0
        default: return 0
        }
    }
}

// MARK: - Detail Sheet

struct BadgeDetailSheet: View {
    let definition: BadgeCatalog.Definition
    let earned: Badge?
    let stats: UserStats?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer(minLength: 20)
                Image(systemName: definition.iconSFSymbol)
                    .font(.system(size: 80))
                    .foregroundStyle(earned != nil ? AppColors.primaryAccent : Color.secondary)
                    .saturation(earned != nil ? 1.0 : 0.1)
                Text(LocalizedStringKey(definition.titleKey))
                    .font(.title2.weight(.bold))
                Text(LocalizedStringKey(definition.descriptionKey))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                if let earned {
                    HStack {
                        Text(LocalizedStringKey("badge.detail.earnedAt"))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(earned.earnedAt, style: .date)
                    }
                    .padding(.horizontal, 24)
                } else if definition.category == .aggregate {
                    let current = BadgeTileView.fieldValue(field: definition.statsField ?? "", stats: stats)
                    HStack {
                        Text(LocalizedStringKey("badge.detail.progress"))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(current)/\(definition.threshold)")
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 24)
                    ProgressView(value: BadgeTileView.progress(definition: definition, stats: stats))
                        .tint(AppColors.primaryAccent)
                        .padding(.horizontal, 24)
                }

                Spacer()
            }
            .navigationTitle(LocalizedStringKey(definition.titleKey))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

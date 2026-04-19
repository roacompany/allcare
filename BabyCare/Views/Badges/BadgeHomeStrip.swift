import SwiftUI

/// 홈 상단 배지 스트립. 최근 획득 5개 + "전체 보기". 0개일 때는 empty prompt.
struct BadgeHomeStrip: View {
    @Environment(AuthViewModel.self) private var authVM
    @Environment(BabyViewModel.self) private var babyVM
    @State private var vm = BadgeViewModel()
    private let presenter = AppState.shared.badgePresenter

    var body: some View {
        Group {
            if !vm.isLoaded {
                // 로드 전에도 공간 유지: empty prompt placeholder 노출 (race 시에도 strip 사라짐 방지)
                emptyPrompt.redacted(reason: .placeholder)
            } else if vm.earned.isEmpty {
                emptyPrompt
            } else {
                stripContent
            }
        }
        .task(id: authVM.currentUserId ?? "") {
            if let uid = authVM.currentUserId {
                await vm.load(userId: uid)
            }
        }
        .onChange(of: presenter.current?.id) { _, newId in
            // 새 배지 획득 스낵바가 뜰 때 strip 자동 reload
            guard newId != nil, let uid = authVM.currentUserId else { return }
            Task { await vm.load(userId: uid) }
        }
    }

    private var emptyPrompt: some View {
        NavigationLink {
            BadgeGalleryView()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "star.fill")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.primaryAccent)
                Text(LocalizedStringKey("badge.home.empty"))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppColors.cardBackground)
            )
        }
        .buttonStyle(.plain)
    }

    private var stripContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(LocalizedStringKey("badge.gallery.title"))
                    .font(.subheadline.weight(.semibold))
                Spacer()
                NavigationLink {
                    BadgeGalleryView()
                } label: {
                    HStack(spacing: 2) {
                        Text(LocalizedStringKey("badge.home.seeAll"))
                            .font(.caption)
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                    }
                    .foregroundStyle(.secondary)
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(vm.recentBadges, id: \.id) { badge in
                        if let def = BadgeCatalog.definition(id: badge.id) {
                            VStack(spacing: 4) {
                                Image(systemName: def.iconSFSymbol)
                                    .font(.system(size: 26))
                                    .foregroundStyle(AppColors.primaryAccent)
                                    .frame(width: 56, height: 56)
                                    .background(AppColors.cardBackground)
                                    .clipShape(Circle())
                                Text(LocalizedStringKey(def.titleKey))
                                    .font(.caption2)
                                    .lineLimit(1)
                                    .frame(width: 60)
                            }
                        }
                    }
                    NavigationLink {
                        BadgeGalleryView()
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 20))
                                .foregroundStyle(.secondary)
                                .frame(width: 56, height: 56)
                                .background(
                                    Circle().stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                                )
                            Text(LocalizedStringKey("badge.home.seeAll"))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

}

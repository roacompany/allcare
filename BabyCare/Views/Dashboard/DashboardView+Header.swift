import SwiftUI

extension DashboardView {
    // MARK: - Header

    var headerView: some View {
        Button {
            if babyVM.babies.count > 1 {
                showBabySelector = true
            }
        } label: {
            HStack(spacing: 8) {
                if let baby = babyVM.selectedBaby {
                    Text(baby.gender.emoji)
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(baby.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(baby.ageText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("아기 선택")
                        .font(.headline)
                        .foregroundStyle(.primary)
                }

                if babyVM.babies.count > 1 {
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .confirmationDialog("아기 선택", isPresented: $showBabySelector, titleVisibility: .visible) {
            ForEach(babyVM.babies) { baby in
                Button(baby.name) {
                    babyVM.selectBaby(baby)
                    Task { await loadData() }
                }
            }
            Button("취소", role: .cancel) {}
        }
    }

    // MARK: - Alert Banners

    @ViewBuilder
    var alertBannersSection: some View {
        VStack(spacing: 8) {
            // 접종 지연 알림
            if !healthVM.overdueVaccinations.isEmpty {
                DashboardAlertBanner(
                    icon: "exclamationmark.triangle.fill",
                    message: "접종 지연 \(healthVM.overdueVaccinations.count)건",
                    color: .red
                )
            }

            // 접종 예정 알림
            if !healthVM.upcomingVaccinations.isEmpty {
                DashboardAlertBanner(
                    icon: "syringe.fill",
                    message: "30일 이내 접종 \(healthVM.upcomingVaccinations.count)건",
                    color: .orange
                )
            }

            // 재고 부족 알림
            ForEach(productVM.lowStockProducts.prefix(2)) { product in
                NavigationLink {
                    ProductDetailView(product: product)
                } label: {
                    DashboardAlertBanner(
                        icon: "bag.fill",
                        message: "재고 부족: \(product.name)",
                        color: AppColors.temperatureColor
                    )
                }
                .buttonStyle(.plain)
            }

            // 유통기한 임박 알림
            if !productVM.expiringSoonProducts.isEmpty {
                DashboardAlertBanner(
                    icon: "clock.badge.exclamationmark.fill",
                    message: "유통기한 임박 \(productVM.expiringSoonProducts.count)건",
                    color: .yellow
                )
            }
        }
    }

    // MARK: - AI Advice Shortcut

    var aiAdviceShortcut: some View {
        NavigationLink {
            AIAdviceView()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "bubble.left.and.text.bubble.right.fill")
                    .font(.title3)
                    .foregroundStyle(.purple)

                VStack(alignment: .leading, spacing: 2) {
                    Text("AI 육아 조언")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    Text("궁금한 점을 물어보세요")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.purple.opacity(0.06))
            )
        }
    }

    // MARK: - Sound Shortcut

    var soundShortcutCard: some View {
        let player = SoundPlayerService.shared

        return Group {
            if player.isPlaying, let sound = player.currentSound {
                // 재생 중: 미니 플레이어
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.15))
                            .frame(width: 42, height: 42)
                        Image(systemName: sound.icon)
                            .font(.system(size: 18))
                            .foregroundStyle(.blue)
                            .symbolEffect(.pulse, isActive: true)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(sound.name)
                            .font(.subheadline.weight(.medium))
                        if let timer = player.timerText {
                            Text("타이머 \(timer)")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        } else {
                            Text("재생 중")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    Button { player.togglePlayPause() } label: {
                        Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)

                    Button { player.stop() } label: {
                        Image(systemName: "stop.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.red.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.blue.opacity(0.06))
                )
            } else {
                // 미재생: 소리 바로가기
                NavigationLink {
                    SoundPlayerView()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.title3)
                            .foregroundStyle(.blue)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("아기 소리")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                            Text("백색소음, 자장가 등")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.blue.opacity(0.06))
                    )
                }
            }
        }
    }


}

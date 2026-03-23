import SwiftUI

// MARK: - SoundPlayerView
// 카테고리 칩 + 트랙 목록. 로컬 SoundItem과 원격 SoundTrack을 통합 표시.

struct SoundPlayerView: View {
    @State private var soundPlayer = SoundPlayerService.shared
    @State private var library = SoundLibraryService.shared
    @State private var selectedCategory: SoundTrack.SoundTrackCategory?
    @State private var showTimerPicker = false

    private let timerOptions = [15, 30, 45, 60, 90, 120]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // ── Now Playing 카드
                    nowPlayingSection

                    // ── 카테고리 칩
                    if !library.isLoading {
                        categoryChips
                    }

                    // ── 트랙 목록
                    if library.isLoading {
                        loadingView
                    } else {
                        trackListSection
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("소리")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showTimerPicker) {
                timerSheet
            }
            .task {
                if library.tracks.isEmpty {
                    await library.fetchTracks()
                }
            }
        }
    }

    // MARK: - Now Playing

    @ViewBuilder
    private var nowPlayingSection: some View {
        if soundPlayer.isPlaying || soundPlayer.currentTrack != nil {
            NowPlayingCard(
                name: soundPlayer.currentName ?? "",
                icon: soundPlayer.currentIcon ?? "music.note",
                soundPlayer: soundPlayer,
                showTimerPicker: $showTimerPicker
            )
            .padding(.horizontal)
        }
    }

    // MARK: - Category Chips

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                CategoryChip(
                    label: "전체",
                    icon: "music.note.list",
                    isSelected: selectedCategory == nil
                ) {
                    selectedCategory = nil
                }

                ForEach(availableCategories, id: \.self) { cat in
                    CategoryChip(
                        label: cat.displayName,
                        icon: cat.icon,
                        isSelected: selectedCategory == cat
                    ) {
                        selectedCategory = (selectedCategory == cat) ? nil : cat
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
        }
    }

    private var availableCategories: [SoundTrack.SoundTrackCategory] {
        let used = Set(library.tracks.map(\.category))
        return SoundTrack.SoundTrackCategory.allCases
            .filter { used.contains($0) }
            .sorted { $0.sortPriority < $1.sortPriority }
    }

    // MARK: - Track List

    @ViewBuilder
    private var trackListSection: some View {
        let groups = filteredGroups
        if groups.isEmpty {
            Text("트랙이 없습니다.")
                .foregroundStyle(.secondary)
                .padding()
        } else {
            ForEach(groups, id: \.0) { category, tracks in
                TrackGroupSection(
                    category: category,
                    tracks: tracks,
                    soundPlayer: soundPlayer
                )
            }
        }
    }

    private var filteredGroups: [(SoundTrack.SoundTrackCategory, [SoundTrack])] {
        if let selected = selectedCategory {
            return library.groupedTracks.filter { $0.0 == selected }
        }
        return library.groupedTracks
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("트랙 목록 불러오는 중...")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    // MARK: - Timer Sheet

    private var timerSheet: some View {
        NavigationStack {
            List {
                if soundPlayer.remainingSeconds != nil {
                    Button(role: .destructive) {
                        soundPlayer.cancelTimer()
                        showTimerPicker = false
                    } label: {
                        Label("타이머 해제", systemImage: "timer.circle")
                    }
                }

                Section("자동 종료 시간") {
                    ForEach(timerOptions, id: \.self) { minutes in
                        Button {
                            soundPlayer.startTimer(minutes: minutes)
                            showTimerPicker = false
                        } label: {
                            HStack {
                                Text(timerLabel(minutes))
                                Spacer()
                                if let remaining = soundPlayer.remainingSeconds,
                                   remaining > (minutes - 1) * 60,
                                   remaining <= minutes * 60 {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                }
            }
            .navigationTitle("수면 타이머")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { showTimerPicker = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func timerLabel(_ minutes: Int) -> String {
        if minutes >= 60 {
            let h = minutes / 60
            let m = minutes % 60
            return m == 0 ? "\(h)시간" : "\(h)시간 \(m)분"
        }
        return "\(minutes)분"
    }
}

// MARK: - NowPlayingCard

private struct NowPlayingCard: View {
    let name: String
    let icon: String
    let soundPlayer: SoundPlayerService
    @Binding var showTimerPicker: Bool

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 56, height: 56)
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundStyle(.blue)
                        .symbolEffect(.pulse, isActive: soundPlayer.isPlaying)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(name)
                        .font(.headline)
                    if let timerText = soundPlayer.timerText {
                        Text("타이머: \(timerText)")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    } else if soundPlayer.isBuffering {
                        Text("버퍼링 중...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("재생 중")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Button { soundPlayer.togglePlayPause() } label: {
                    Image(systemName: soundPlayer.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)

                Button { soundPlayer.stop() } label: {
                    Image(systemName: "stop.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.red.opacity(0.7))
                }
                .buttonStyle(.plain)
            }

            // 볼륨 슬라이더
            HStack(spacing: 12) {
                Image(systemName: "speaker.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Slider(value: Binding(
                    get: { Double(soundPlayer.volume) },
                    set: { soundPlayer.setVolume(Float($0)) }
                ), in: 0...1)
                .tint(.blue)
                Image(systemName: "speaker.wave.3.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // 타이머 버튼
            Button {
                showTimerPicker = true
            } label: {
                HStack {
                    Image(systemName: "timer")
                    Text(soundPlayer.remainingSeconds != nil ? "타이머 변경" : "수면 타이머")
                        .font(.subheadline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.blue.opacity(0.1))
                .foregroundStyle(.blue)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - CategoryChip

private struct CategoryChip: View {
    let label: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                Text(label)
                    .font(.caption.weight(.medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.blue : Color(.systemGray6))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - TrackGroupSection

private struct TrackGroupSection: View {
    let category: SoundTrack.SoundTrackCategory
    let tracks: [SoundTrack]
    let soundPlayer: SoundPlayerService

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 섹션 헤더
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .foregroundStyle(.secondary)
                Text(category.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            // 트랙 행 목록
            VStack(spacing: 0) {
                ForEach(tracks) { track in
                    TrackRow(track: track, soundPlayer: soundPlayer)
                    Divider().padding(.leading, 60)
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        }
    }
}

// MARK: - TrackRow

private struct TrackRow: View {
    let track: SoundTrack
    let soundPlayer: SoundPlayerService
    @State private var isDownloading = false

    private var isActive: Bool {
        soundPlayer.currentTrack?.id == track.id && soundPlayer.isPlaying
    }

    var body: some View {
        HStack(spacing: 12) {
            // 아이콘
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(isActive ? Color.blue.opacity(0.15) : Color(.systemGray5))
                    .frame(width: 44, height: 44)
                Image(systemName: track.iconName)
                    .font(.system(size: 18))
                    .foregroundStyle(isActive ? .blue : .secondary)
                    .symbolEffect(.pulse, isActive: isActive)
            }

            // 이름 / 아티스트
            VStack(alignment: .leading, spacing: 2) {
                Text(track.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(isActive ? .blue : .primary)
                if !track.artist.isEmpty && track.artist != "BabyCare" {
                    Text(track.artist)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // 재생 시간
            if track.duration > 0 {
                Text(track.durationText)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            // 다운로드 / 재생 버튼
            if !track.isLocal {
                downloadButton
            }

            // 재생 토글 버튼
            Button {
                if isActive {
                    soundPlayer.stop()
                } else {
                    soundPlayer.play(track)
                }
            } label: {
                Image(systemName: isActive ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(isActive ? .blue : .secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .onTapGesture {
            if isActive {
                soundPlayer.stop()
            } else {
                soundPlayer.play(track)
            }
        }
    }

    @ViewBuilder
    private var downloadButton: some View {
        if soundPlayer.isDownloaded(track) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(.green.opacity(0.7))
        } else if isDownloading {
            ProgressView()
                .scaleEffect(0.7)
                .frame(width: 20, height: 20)
        } else {
            Button {
                isDownloading = true
                Task {
                    await soundPlayer.downloadTrack(track)
                    isDownloading = false
                }
            } label: {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }
}

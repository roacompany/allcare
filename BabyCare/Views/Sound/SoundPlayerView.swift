import SwiftUI

struct SoundPlayerView: View {
    @State private var soundPlayer = SoundPlayerService.shared
    @State private var selectedCategory: SoundItem.SoundCategory?
    @State private var showTimerPicker = false

    private let timerOptions = [0, 15, 30, 45, 60, 90, 120]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Now Playing
                    if let current = soundPlayer.currentSound {
                        nowPlayingCard(current)
                    }

                    // Sound Grid
                    ForEach(SoundItem.byCategory(), id: \.0) { category, items in
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 6) {
                                Image(systemName: category.icon)
                                    .foregroundStyle(.secondary)
                                Text(category.rawValue)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal)

                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 12) {
                                ForEach(items) { sound in
                                    soundButton(sound)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("소리")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showTimerPicker) {
                timerSheet
            }
        }
    }

    // MARK: - Now Playing

    @ViewBuilder
    private func nowPlayingCard(_ sound: SoundItem) -> some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 56, height: 56)
                    Image(systemName: sound.icon)
                        .font(.title2)
                        .foregroundStyle(.blue)
                        .symbolEffect(.pulse, isActive: soundPlayer.isPlaying)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(sound.name)
                        .font(.headline)
                    if let timerText = soundPlayer.timerText {
                        Text("타이머: \(timerText)")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    } else {
                        Text("재생 중")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Button {
                    soundPlayer.togglePlayPause()
                } label: {
                    Image(systemName: soundPlayer.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)

                Button {
                    soundPlayer.stop()
                } label: {
                    Image(systemName: "stop.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.red.opacity(0.7))
                }
                .buttonStyle(.plain)
            }

            // Volume
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

            // Timer button
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
        .padding(.horizontal)
    }

    // MARK: - Sound Button

    private func soundButton(_ sound: SoundItem) -> some View {
        let isActive = soundPlayer.currentSound == sound && soundPlayer.isPlaying

        return Button {
            if isActive {
                soundPlayer.stop()
            } else {
                soundPlayer.play(sound)
            }
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(isActive ? Color.blue.opacity(0.15) : Color(.systemGray6))
                        .frame(height: 72)
                    Image(systemName: sound.icon)
                        .font(.title2)
                        .foregroundStyle(isActive ? .blue : .secondary)
                        .symbolEffect(.pulse, isActive: isActive)
                }
                Text(sound.name)
                    .font(.caption)
                    .foregroundStyle(isActive ? .blue : .primary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
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
                    ForEach(timerOptions.filter { $0 > 0 }, id: \.self) { minutes in
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

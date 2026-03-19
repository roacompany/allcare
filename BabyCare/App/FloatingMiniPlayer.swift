import SwiftUI
import AVFoundation

// MARK: - Floating Mini Player

struct FloatingMiniPlayer: View {
    @State private var showSoundPlayer = false
    private var player: SoundPlayerService { SoundPlayerService.shared }

    var body: some View {
        if player.isPlaying, let sound = player.currentSound {
            HStack(spacing: 10) {
                Image(systemName: sound.icon)
                    .font(.system(size: 14))
                    .foregroundStyle(.white)
                    .symbolEffect(.pulse, isActive: true)

                Text(sound.name)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                if let timer = player.timerText {
                    Text(timer)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.7))
                }

                Spacer()

                Button { player.togglePlayPause() } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button { player.stop() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(.blue.gradient)
                    .shadow(color: .blue.opacity(0.3), radius: 8, y: 4)
            )
            .padding(.horizontal, 20)
            .contentShape(Capsule())
            .onTapGesture { showSoundPlayer = true }
            .sheet(isPresented: $showSoundPlayer) {
                SoundPlayerView()
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.spring(duration: 0.3), value: player.isPlaying)
        }
    }
}

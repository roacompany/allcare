import SwiftUI
import AVFoundation

// MARK: - Floating Mini Player
// SoundItem(로컬) 및 SoundTrack(스트리밍) 모두 표시 지원.

struct FloatingMiniPlayer: View {
    @State private var showSoundPlayer = false
    private var player: SoundPlayerService { SoundPlayerService.shared }

    // 현재 재생 중인 아이콘과 이름을 통합 프로퍼티에서 가져옴
    private var displayName: String? { player.currentName }
    private var displayIcon: String? { player.currentIcon }

    var body: some View {
        if player.isPlaying, let name = displayName, let icon = displayIcon {
            HStack(spacing: 10) {
                // 아이콘 (버퍼링 중이면 스피너)
                if player.isBuffering {
                    ProgressView()
                        .scaleEffect(0.8)
                        .frame(width: 18, height: 18)
                        .tint(.white)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundStyle(.white)
                        .symbolEffect(.pulse, isActive: true)
                }

                Text(name)
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

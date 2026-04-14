import Foundation

@MainActor @Observable
final class SoundPlayerViewModel {
    var soundPlayer: SoundPlayerService = SoundPlayerService.shared
    var library: SoundLibraryService = SoundLibraryService.shared

    // MARK: - Library

    func fetchTracksIfNeeded() async {
        if library.tracks.isEmpty {
            await library.fetchTracks()
        }
    }
}

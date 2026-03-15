import SwiftUI
import AVKit
import AVFoundation

struct PlayerView: View {
    let streamUrl: String
    let title: String
    let contentId: String
    let contentType: ContentType
    let poster: String?
    let season: Int?
    let episode: Int?
    let headers: [String: String]?

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: PlayerViewModel

    init(
        streamUrl: String,
        title: String,
        contentId: String,
        contentType: ContentType,
        poster: String? = nil,
        season: Int? = nil,
        episode: Int? = nil,
        headers: [String: String]? = nil
    ) {
        self.streamUrl = streamUrl
        self.title = title
        self.contentId = contentId
        self.contentType = contentType
        self.poster = poster
        self.season = season
        self.episode = episode
        self.headers = headers
        _viewModel = StateObject(wrappedValue: PlayerViewModel())
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let player = viewModel.player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
                    .onDisappear {
                        viewModel.saveProgress(
                            contentId: contentId,
                            contentType: contentType,
                            title: title,
                            poster: poster,
                            season: season,
                            episode: episode
                        )
                        player.pause()
                    }
            } else if viewModel.isLoading {
                loadingView
            } else if let error = viewModel.errorMessage {
                errorView(error)
            }
        }
        .ignoresSafeArea()
        .navigationBarHidden(true)
        .task {
            await viewModel.loadPlayer(
                urlString: streamUrl,
                headers: headers,
                title: title,
                contentId: contentId,
                contentType: contentType,
                season: season,
                episode: episode
            )
        }
        .onDisappear {
            viewModel.cleanup()
        }
    }

    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(2.5)
                .tint(.white)
            Text("Loading \(title)...")
                .font(.title3)
                .foregroundStyle(.white.opacity(0.8))
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 70))
                .foregroundStyle(.orange)
            Text("Playback Error")
                .font(.title.bold())
                .foregroundStyle(.white)
            Text(message)
                .font(.body)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 600)
            Button("Go Back") {
                dismiss()
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 14)
            .background(.white.opacity(0.2))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}

// MARK: - Player ViewModel

@MainActor
final class PlayerViewModel: ObservableObject {
    @Published var player: AVPlayer?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var timeObserver: Any?
    private var progressStorage = WatchProgressStorage.shared

    func loadPlayer(
        urlString: String,
        headers: [String: String]?,
        title: String,
        contentId: String,
        contentType: ContentType,
        season: Int?,
        episode: Int?
    ) async {
        isLoading = true
        errorMessage = nil

        guard let url = URL(string: urlString) else {
            errorMessage = "Invalid stream URL"
            isLoading = false
            return
        }

        // Build AVPlayerItem with custom headers if needed
        let playerItem: AVPlayerItem
        if let headers = headers, !headers.isEmpty {
            var request = URLRequest(url: url)
            headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
            let asset = AVURLAsset(url: url, options: [
                "AVURLAssetHTTPHeaderFieldsKey": headers
            ])
            playerItem = AVPlayerItem(asset: asset)
        } else {
            playerItem = AVPlayerItem(url: url)
        }

        let newPlayer = AVPlayer(playerItem: playerItem)

        // Restore watch progress if available
        if let existing = progressStorage.getProgress(id: contentId) {
            let episodeMatches: Bool
            if let s = season, let e = episode {
                episodeMatches = existing.season == s && existing.episode == e
            } else {
                episodeMatches = existing.season == nil && existing.episode == nil
            }

            if episodeMatches && existing.progressFraction > 0.02 && !existing.isFinished {
                let seekTime = CMTime(value: existing.positionMs / 1000, timescale: 1)
                await newPlayer.seek(to: seekTime, toleranceBefore: .zero, toleranceAfter: .zero)
            }
        }

        // Configure audio session for Apple TV
        setupAudioSession()

        newPlayer.play()
        player = newPlayer
        isLoading = false

        // Start tracking progress
        startProgressTracking(
            player: newPlayer,
            contentId: contentId,
            contentType: contentType,
            title: title,
            season: season,
            episode: episode
        )
    }

    private func setupAudioSession() {
        // tvOS audio session configuration
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session setup failed: \(error)")
        }
    }

    private func startProgressTracking(
        player: AVPlayer,
        contentId: String,
        contentType: ContentType,
        title: String,
        season: Int?,
        episode: Int?
    ) {
        // Update progress every 10 seconds
        let interval = CMTime(seconds: 10, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self,
                  let duration = player.currentItem?.duration,
                  duration.isNumeric else { return }

            let positionMs = Int64(time.seconds * 1000)
            let durationMs = Int64(duration.seconds * 1000)

            Task { @MainActor in
                self.progressStorage.updateProgress(
                    id: contentId,
                    contentType: contentType,
                    title: title,
                    positionMs: positionMs,
                    durationMs: durationMs,
                    season: season,
                    episode: episode
                )
            }
        }
    }

    func saveProgress(
        contentId: String,
        contentType: ContentType,
        title: String,
        poster: String?,
        season: Int?,
        episode: Int?
    ) {
        guard let player = player,
              let duration = player.currentItem?.duration,
              duration.isNumeric else { return }

        let positionMs = Int64(player.currentTime().seconds * 1000)
        let durationMs = Int64(duration.seconds * 1000)

        progressStorage.updateProgress(
            id: contentId,
            contentType: contentType,
            title: title,
            poster: poster,
            positionMs: positionMs,
            durationMs: durationMs,
            season: season,
            episode: episode
        )
    }

    func cleanup() {
        if let observer = timeObserver, let player = player {
            player.removeTimeObserver(observer)
        }
        player?.pause()
        player = nil
    }
}

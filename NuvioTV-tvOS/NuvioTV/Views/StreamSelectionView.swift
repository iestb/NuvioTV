import SwiftUI

struct StreamSelectionView: View {
    let contentId: String
    let contentType: ContentType
    let title: String
    let poster: String?
    let videoId: String?
    let season: Int?
    let episode: Int?

    @StateObject private var viewModel = StreamSelectionViewModel()
    @State private var selectedStream: Stream?

    private var effectiveVideoId: String {
        videoId ?? contentId
    }

    private var episodeLabel: String? {
        guard let s = season, let e = episode else { return nil }
        return "Season \(s) · Episode \(e)"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if viewModel.isLoading {
                    loadingView
                } else if let error = viewModel.errorMessage, viewModel.addonStreams.isEmpty {
                    errorView(error)
                } else {
                    streamList
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $selectedStream) { stream in
                if let url = stream.streamUrl {
                    PlayerView(
                        streamUrl: url,
                        title: title,
                        contentId: contentId,
                        contentType: contentType,
                        poster: poster,
                        season: season,
                        episode: episode,
                        headers: stream.behaviorHints?.proxyHeaders?.request
                    )
                }
            }
        }
        .task {
            await viewModel.loadStreams(type: contentType.apiString, id: effectiveVideoId)
        }
    }

    // MARK: - Stream List

    private var streamList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                // Header info
                headerView

                // Stream groups by addon
                ForEach(viewModel.addonStreams) { addonGroup in
                    addonSection(addonGroup)
                }

                Spacer(minLength: 60)
            }
            .padding(.horizontal, 60)
            .padding(.top, 20)
        }
    }

    private var headerView: some View {
        HStack(spacing: 20) {
            // Poster
            if let posterUrl = poster, let url = URL(string: posterUrl) {
                AsyncImage(url: url) { phase in
                    if case .success(let image) = phase {
                        image.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        Color.gray.opacity(0.3)
                    }
                }
                .frame(width: 100, height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.title.bold())
                    .foregroundStyle(.primary)

                if let episodeLabel = episodeLabel {
                    Text(episodeLabel)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                let totalStreams = viewModel.addonStreams.reduce(0) { $0 + $1.streams.count }
                if totalStreams > 0 {
                    Text("\(totalStreams) stream\(totalStreams == 1 ? "" : "s") available")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.top, 20)
    }

    @ViewBuilder
    private func addonSection(_ group: AddonStreams) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Addon header
            HStack(spacing: 10) {
                if let logoUrl = group.addonLogo, let url = URL(string: logoUrl) {
                    AsyncImage(url: url) { phase in
                        if case .success(let image) = phase {
                            image.resizable().scaledToFit()
                        }
                    }
                    .frame(width: 24, height: 24)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                } else {
                    Image(systemName: "puzzlepiece.extension.fill")
                        .foregroundStyle(.secondary)
                }

                Text(group.addonName)
                    .font(.title3.bold())
                    .foregroundStyle(.primary)

                Spacer()

                Text("\(group.streams.count) stream\(group.streams.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Stream items
            VStack(spacing: 6) {
                ForEach(group.streams) { stream in
                    StreamRowView(stream: stream) {
                        if stream.isTorrent {
                            // TODO: Handle torrent
                        } else if stream.isExternal {
                            // TODO: Handle external URL
                        } else {
                            selectedStream = stream
                        }
                    }
                }
            }
        }
    }

    // MARK: - States

    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(2)
                .tint(.white)
            Text("Finding streams...")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 24) {
            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                .font(.system(size: 70))
                .foregroundStyle(.secondary)
            Text("No Streams Found")
                .font(.title.bold())
                .foregroundStyle(.primary)
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 600)
        }
    }
}

// MARK: - Stream Row

struct StreamRowView: View {
    let stream: Stream
    let onSelect: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                // Play icon
                ZStack {
                    Circle()
                        .fill(isFocused ? .white : .white.opacity(0.2))
                        .frame(width: 44, height: 44)

                    Image(systemName: streamIcon)
                        .font(.callout.bold())
                        .foregroundStyle(isFocused ? .black : .white)
                }

                // Stream info
                VStack(alignment: .leading, spacing: 4) {
                    Text(stream.displayName)
                        .font(.callout.bold())
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    if let desc = stream.displayDescription, desc != stream.displayName {
                        Text(desc)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer()

                // Quality badge
                if let quality = stream.qualityBadge {
                    Text(quality)
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(quality == "4K" ? .blue.opacity(0.8) : .green.opacity(0.8))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .foregroundStyle(.white)
                }

                // Type badge
                if stream.isTorrent {
                    Image(systemName: "arrow.down.circle")
                        .foregroundStyle(.orange)
                } else if stream.isExternal {
                    Image(systemName: "arrow.up.right.square")
                        .foregroundStyle(.secondary)
                } else {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .background(isFocused ? .white.opacity(0.15) : .white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .scaleEffect(isFocused ? 1.02 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isFocused)
        }
        .buttonStyle(.plain)
        .focused($isFocused)
    }

    private var streamIcon: String {
        if stream.isTorrent { return "arrow.down.circle.fill" }
        if stream.isExternal { return "arrow.up.right.circle.fill" }
        return "play.fill"
    }
}

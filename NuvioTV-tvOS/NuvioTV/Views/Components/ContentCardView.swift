import SwiftUI

// MARK: - Content Card (used in catalogs)

struct ContentCardView: View {
    let item: MetaPreview
    let width: CGFloat
    let height: CGFloat

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomLeading) {
                posterImage
                    .frame(width: width, height: height)
                    .clipShape(RoundedRectangle(cornerRadius: isFocused ? 12 : 8))
                    .scaleEffect(isFocused ? 1.05 : 1.0)
                    .shadow(radius: isFocused ? 20 : 5)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isFocused)

                if let rating = item.ratingString {
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                        Text(rating)
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                    }
                    .padding(6)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .padding(8)
                    .opacity(isFocused ? 1 : 0)
                    .animation(.easeInOut(duration: 0.2), value: isFocused)
                }
            }

            if isFocused {
                Text(item.name)
                    .font(.caption.bold())
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .frame(width: width, alignment: .leading)
                    .transition(.opacity)
            }
        }
        .focused($isFocused)
    }

    @ViewBuilder
    private var posterImage: some View {
        if let posterUrl = item.poster, let url = URL(string: posterUrl) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    placeholderView
                case .empty:
                    placeholderView
                        .overlay(ProgressView().tint(.white))
                @unknown default:
                    placeholderView
                }
            }
        } else {
            placeholderView
        }
    }

    private var placeholderView: some View {
        ZStack {
            LinearGradient(
                colors: [.blue.opacity(0.6), .purple.opacity(0.4)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(spacing: 8) {
                Image(systemName: item.type == .movie ? "film" : "tv")
                    .font(.largeTitle)
                    .foregroundStyle(.white.opacity(0.7))
                Text(item.name)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
        }
    }
}

// MARK: - Wide Content Card (for continue watching)

struct WideContentCardView: View {
    let progress: WatchProgress
    let width: CGFloat
    let height: CGFloat

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .bottomLeading) {
                backdropImage
                    .frame(width: width, height: height)
                    .clipShape(RoundedRectangle(cornerRadius: isFocused ? 12 : 8))
                    .scaleEffect(isFocused ? 1.05 : 1.0)
                    .shadow(radius: isFocused ? 20 : 5)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isFocused)

                // Progress bar
                VStack(spacing: 0) {
                    Spacer()
                    ProgressView(value: progress.progressFraction)
                        .progressViewStyle(.linear)
                        .tint(.red)
                        .scaleEffect(x: 1, y: 2)
                }
                .frame(width: width, height: height)
                .clipShape(RoundedRectangle(cornerRadius: isFocused ? 12 : 8))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(progress.title)
                    .font(.caption.bold())
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if let season = progress.season, let episode = progress.episode {
                    Text("S\(String(format: "%02d", season))E\(String(format: "%02d", episode))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: width, alignment: .leading)
        }
        .focused($isFocused)
    }

    @ViewBuilder
    private var backdropImage: some View {
        let imageUrl = progress.backdrop ?? progress.poster
        if let urlStr = imageUrl, let url = URL(string: urlStr) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                default:
                    placeholderView
                }
            }
        } else {
            placeholderView
        }
    }

    private var placeholderView: some View {
        LinearGradient(
            colors: [.gray.opacity(0.5), .gray.opacity(0.3)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Hero Banner View

struct HeroBannerView: View {
    let item: MetaPreview

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Backdrop
            if let backdrop = item.background ?? item.poster, let url = URL(string: backdrop) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    default:
                        Color.gray.opacity(0.3)
                    }
                }
            } else {
                LinearGradient(
                    colors: [.blue.opacity(0.6), .purple.opacity(0.4)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }

            // Gradient overlay
            LinearGradient(
                colors: [.clear, .black.opacity(0.8)],
                startPoint: .center,
                endPoint: .bottom
            )

            // Content
            VStack(alignment: .leading, spacing: 12) {
                if let logo = item.logo, let url = URL(string: logo) {
                    AsyncImage(url: url) { phase in
                        if case .success(let image) = phase {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 80)
                        } else {
                            Text(item.name)
                                .font(.largeTitle.bold())
                                .foregroundStyle(.white)
                        }
                    }
                } else {
                    Text(item.name)
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)
                }

                HStack(spacing: 12) {
                    if let rating = item.ratingString {
                        Label(rating, systemImage: "star.fill")
                            .font(.callout)
                            .foregroundStyle(.yellow)
                    }

                    if !item.genres.isEmpty {
                        Text(item.genres.prefix(3).joined(separator: " • "))
                            .font(.callout)
                            .foregroundStyle(.white.opacity(0.8))
                    }

                    if let release = item.releaseInfo {
                        Text(release)
                            .font(.callout)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }

                if let desc = item.description {
                    Text(desc)
                        .font(.callout)
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(3)
                        .frame(maxWidth: 600, alignment: .leading)
                }
            }
            .padding(60)
        }
    }
}

// MARK: - Catalog Row View

struct CatalogRowView<Item: Identifiable>: View {
    let title: String
    let subtitle: String?
    let items: [Item]
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    let onSeeAll: (() -> Void)?
    let content: (Item) -> AnyView

    init(
        title: String,
        subtitle: String? = nil,
        items: [Item],
        cardWidth: CGFloat = 200,
        cardHeight: CGFloat = 300,
        onSeeAll: (() -> Void)? = nil,
        @ViewBuilder content: @escaping (Item) -> some View
    ) {
        self.title = title
        self.subtitle = subtitle
        self.items = items
        self.cardWidth = cardWidth
        self.cardHeight = cardHeight
        self.onSeeAll = onSeeAll
        self.content = { AnyView(content($0)) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.title2.bold())
                        .foregroundStyle(.primary)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if let onSeeAll = onSeeAll {
                    Button("See All") {
                        onSeeAll()
                    }
                    .font(.callout)
                }
            }
            .padding(.horizontal, 60)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(items) { item in
                        content(item)
                            .frame(width: cardWidth)
                    }
                }
                .padding(.horizontal, 60)
                .padding(.vertical, 10) // Space for focus scale
            }
        }
    }
}

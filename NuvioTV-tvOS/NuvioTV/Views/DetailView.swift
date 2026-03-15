import SwiftUI

struct DetailView: View {
    let contentId: String
    let contentType: ContentType
    let previewItem: MetaPreview?

    @StateObject private var viewModel = DetailViewModel()
    @State private var selectedSeason: Int = 1
    @State private var selectedEpisode: Video?
    @State private var navigateToStream = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            backgroundView

            if viewModel.isLoading {
                loadingView
            } else if let meta = viewModel.meta {
                detailContent(meta: meta)
            } else if let preview = previewItem {
                // Show preview while loading
                previewContent(preview: preview)
            }
        }
        .task {
            await viewModel.loadMeta(id: contentId, type: contentType)
            if let meta = viewModel.meta, meta.isSeries {
                selectedSeason = viewModel.availableSeasons.first ?? 1
                viewModel.selectSeason(selectedSeason)
            }
        }
        .navigationBarHidden(false)
    }

    // MARK: - Background

    @ViewBuilder
    private var backgroundView: some View {
        let backdropUrl = viewModel.meta?.backdropUrl ?? previewItem?.background ?? previewItem?.poster
        if let urlStr = backdropUrl, let url = URL(string: urlStr) {
            AsyncImage(url: url) { phase in
                if case .success(let image) = phase {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .ignoresSafeArea()
                        .overlay(
                            LinearGradient(
                                colors: [.black.opacity(0.3), .black.opacity(0.9)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
            }
        }
    }

    private var loadingView: some View {
        ProgressView()
            .scaleEffect(2)
            .tint(.white)
    }

    // MARK: - Full meta detail

    @ViewBuilder
    private func detailContent(meta: Meta) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                // Hero section
                heroSection(meta: meta)
                    .frame(height: 540)

                // Content below hero
                VStack(alignment: .leading, spacing: 40) {
                    if meta.isSeries {
                        seriesSection(meta: meta)
                    }

                    // Description
                    if let desc = meta.description {
                        descriptionSection(desc)
                    }

                    // Cast
                    if !meta.cast.isEmpty || !meta.castMembers.isEmpty {
                        castSection(meta: meta)
                    }

                    // Details
                    detailsSection(meta: meta)

                    Spacer(minLength: 80)
                }
                .padding(.horizontal, 60)
                .padding(.top, 40)
            }
        }
    }

    // MARK: - Hero Section

    @ViewBuilder
    private func heroSection(meta: Meta) -> some View {
        ZStack(alignment: .bottomLeading) {
            // Already shown in background, just show content
            VStack(alignment: .leading, spacing: 16) {
                Spacer()

                // Logo or title
                if let logo = meta.logo, let url = URL(string: logo) {
                    AsyncImage(url: url) { phase in
                        if case .success(let image) = phase {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 100)
                        } else {
                            titleText(meta.name)
                        }
                    }
                } else {
                    titleText(meta.name)
                }

                // Meta info row
                HStack(spacing: 16) {
                    if let rating = meta.ratingString {
                        Label(rating, systemImage: "star.fill")
                            .foregroundStyle(.yellow)
                            .font(.callout.bold())
                    }

                    if let age = meta.ageRating {
                        Text(age)
                            .font(.caption.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.white.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .foregroundStyle(.white)
                    }

                    if let runtime = meta.runtime {
                        Label(runtime, systemImage: "clock")
                            .font(.callout)
                            .foregroundStyle(.white.opacity(0.8))
                    }

                    if let release = meta.releaseInfo {
                        Text(release)
                            .font(.callout)
                            .foregroundStyle(.white.opacity(0.7))
                    }

                    if !meta.genres.isEmpty {
                        Text(meta.formattedGenres)
                            .font(.callout)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }

                // Action buttons
                HStack(spacing: 16) {
                    if meta.isMovie {
                        NavigationLink {
                            StreamSelectionView(
                                contentId: meta.id,
                                contentType: meta.type,
                                title: meta.name,
                                poster: meta.poster,
                                videoId: meta.id,
                                season: nil,
                                episode: nil
                            )
                        } label: {
                            Label("Watch Now", systemImage: "play.fill")
                                .font(.callout.bold())
                                .padding(.horizontal, 24)
                                .padding(.vertical, 14)
                                .background(.white)
                                .foregroundStyle(.black)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }

                    if meta.isSeries, let ep = viewModel.episodes.first {
                        NavigationLink {
                            StreamSelectionView(
                                contentId: meta.id,
                                contentType: meta.type,
                                title: meta.name,
                                poster: meta.poster,
                                videoId: ep.id,
                                season: ep.season,
                                episode: ep.episode
                            )
                        } label: {
                            Label("Play S01E01", systemImage: "play.fill")
                                .font(.callout.bold())
                                .padding(.horizontal, 24)
                                .padding(.vertical, 14)
                                .background(.white)
                                .foregroundStyle(.black)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }

                    // Trailer button
                    if !meta.trailerYtIds.isEmpty {
                        Button {
                            // TODO: Open trailer
                        } label: {
                            Label("Trailer", systemImage: "play.rectangle")
                                .font(.callout)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 14)
                                .background(.white.opacity(0.2))
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
            }
            .padding(60)
        }
    }

    private func titleText(_ name: String) -> some View {
        Text(name)
            .font(.system(size: 52, weight: .bold))
            .foregroundStyle(.white)
    }

    // MARK: - Series Episodes Section

    @ViewBuilder
    private func seriesSection(meta: Meta) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            // Season picker
            if viewModel.availableSeasons.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(viewModel.availableSeasons, id: \.self) { season in
                            Button("Season \(season)") {
                                viewModel.selectSeason(season)
                                selectedSeason = season
                            }
                            .font(.callout.bold())
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(selectedSeason == season ? .white : .white.opacity(0.2))
                            .foregroundStyle(selectedSeason == season ? .black : .white)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }

            // Episode list
            VStack(spacing: 8) {
                ForEach(viewModel.episodes) { episode in
                    NavigationLink {
                        StreamSelectionView(
                            contentId: meta.id,
                            contentType: meta.type,
                            title: meta.name,
                            poster: meta.poster,
                            videoId: episode.id,
                            season: episode.season,
                            episode: episode.episode
                        )
                    } label: {
                        EpisodeRowView(episode: episode)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Description Section

    private func descriptionSection(_ desc: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Overview")
                .font(.title2.bold())
                .foregroundStyle(.primary)

            Text(desc)
                .font(.body)
                .foregroundStyle(.secondary)
                .lineLimit(nil)
        }
    }

    // MARK: - Cast Section

    @ViewBuilder
    private func castSection(meta: Meta) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Cast & Crew")
                .font(.title2.bold())
                .foregroundStyle(.primary)

            if !meta.castMembers.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(meta.castMembers, id: \.name) { member in
                            CastMemberCard(member: member)
                        }
                    }
                }
            } else {
                Text(meta.cast.prefix(10).joined(separator: ", "))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Details Section

    @ViewBuilder
    private func detailsSection(meta: Meta) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Details")
                .font(.title2.bold())
                .foregroundStyle(.primary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 12) {
                if !meta.director.isEmpty {
                    DetailRow(label: "Director", value: meta.director.joined(separator: ", "))
                }
                if let country = meta.country {
                    DetailRow(label: "Country", value: country)
                }
                if let language = meta.language {
                    DetailRow(label: "Language", value: language)
                }
                if let status = meta.status {
                    DetailRow(label: "Status", value: status)
                }
                if let imdbId = meta.imdbId {
                    DetailRow(label: "IMDb", value: imdbId)
                }
            }
        }
    }

    // MARK: - Preview content (shown while loading)

    @ViewBuilder
    private func previewContent(_ preview: MetaPreview) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Spacer()
            Text(preview.name)
                .font(.system(size: 52, weight: .bold))
                .foregroundStyle(.white)
                .padding(60)

            ProgressView("Loading details...")
                .tint(.white)
                .padding(.horizontal, 60)
        }
    }
}

// MARK: - Episode Row

struct EpisodeRowView: View {
    let episode: Video
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 16) {
            // Thumbnail
            ZStack {
                if let thumb = episode.thumbnail, let url = URL(string: thumb) {
                    AsyncImage(url: url) { phase in
                        if case .success(let image) = phase {
                            image.resizable().aspectRatio(contentMode: .fill)
                        } else {
                            Color.gray.opacity(0.3)
                        }
                    }
                } else {
                    Color.gray.opacity(0.3)
                    Image(systemName: "play.fill")
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .frame(width: 160, height: 90)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(episode.episodeLabel)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                Text(episode.title)
                    .font(.callout.bold())
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                if let overview = episode.overview {
                    Text(overview)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            if let runtime = episode.runtime {
                Text("\(runtime)m")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(isFocused ? .white.opacity(0.15) : .clear)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .scaleEffect(isFocused ? 1.02 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isFocused)
        .focused($isFocused)
    }
}

// MARK: - Cast Member Card

struct CastMemberCard: View {
    let member: MetaCastMember
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 8) {
            AsyncImage(url: member.photo.flatMap { URL(string: $0) }) { phase in
                if case .success(let image) = phase {
                    image.resizable().aspectRatio(contentMode: .fill)
                } else {
                    Circle()
                        .fill(.gray.opacity(0.4))
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundStyle(.gray)
                        )
                }
            }
            .frame(width: 100, height: 100)
            .clipShape(Circle())
            .scaleEffect(isFocused ? 1.1 : 1.0)
            .animation(.spring(response: 0.2), value: isFocused)

            Text(member.name)
                .font(.caption.bold())
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            if let character = member.character {
                Text(character)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(width: 100)
        .focused($isFocused)
    }
}

// MARK: - Detail Row

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout)
                .foregroundStyle(.primary)
        }
    }
}

// MARK: - Meta language extension (for DetailView)
extension Meta {
    var language: String? { nil } // Placeholder - Meta model can be extended
}

import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @State private var selectedItem: MetaPreview?
    @State private var showNoAddons = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if viewModel.isLoading && viewModel.sections.isEmpty {
                    loadingView
                } else if viewModel.sections.isEmpty && viewModel.continueWatching.isEmpty {
                    emptyStateView
                } else {
                    contentView
                }
            }
            .navigationDestination(item: $selectedItem) { item in
                DetailView(
                    contentId: item.id,
                    contentType: item.type,
                    previewItem: item
                )
            }
        }
        .task {
            await viewModel.loadContent()
        }
        .refreshable {
            await viewModel.refresh()
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var contentView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 40) {
                // Hero banner
                if let featured = viewModel.featuredItem {
                    Button {
                        selectedItem = featured
                    } label: {
                        HeroBannerView(item: featured)
                            .frame(height: 600)
                    }
                    .buttonStyle(.plain)
                }

                // Continue watching
                if !viewModel.continueWatching.isEmpty {
                    CatalogRowView(
                        title: "Continue Watching",
                        items: viewModel.continueWatching,
                        cardWidth: 300,
                        cardHeight: 170
                    ) { progress in
                        NavigationLink {
                            StreamSelectionView(
                                contentId: progress.id,
                                contentType: progress.contentType,
                                title: progress.title,
                                poster: progress.poster,
                                videoId: progress.videoId,
                                season: progress.season,
                                episode: progress.episode
                            )
                        } label: {
                            WideContentCardView(
                                progress: progress,
                                width: 300,
                                height: 170
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Catalog sections
                ForEach(viewModel.sections) { section in
                    CatalogRowView(
                        title: section.title,
                        subtitle: section.addonName,
                        items: section.items,
                        cardWidth: 200,
                        cardHeight: 300
                    ) { item in
                        Button {
                            selectedItem = item
                        } label: {
                            ContentCardView(item: item, width: 200, height: 300)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer(minLength: 60)
            }
        }
    }

    // MARK: - States

    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(2)
                .tint(.white)
            Text("Loading content...")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "puzzlepiece.extension")
                .font(.system(size: 80))
                .foregroundStyle(.secondary)

            Text("No Addons Installed")
                .font(.title.bold())
                .foregroundStyle(.primary)

            Text("Go to Settings to install Stremio addons and browse content.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 600)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

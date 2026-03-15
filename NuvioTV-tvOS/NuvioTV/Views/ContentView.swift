import SwiftUI

struct ContentView: View {
    @StateObject private var addonStorage = AddonStorage.shared

    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)

            SearchView()
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .tag(1)

            LibraryView()
                .tabItem {
                    Label("Library", systemImage: "film.stack")
                }
                .tag(2)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(3)
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Library View

struct LibraryView: View {
    @ObservedObject private var watchProgressStorage = WatchProgressStorage.shared
    @State private var selectedItem: WatchProgress?

    private let columns = [
        GridItem(.adaptive(minimum: 260, maximum: 320), spacing: 20)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if watchProgressStorage.progressItems.isEmpty {
                    emptyView
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 30) {
                            ForEach(watchProgressStorage.continueWatchingItems) { progress in
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
                        .padding(60)
                    }
                }
            }
            .navigationTitle("Continue Watching")
        }
    }

    private var emptyView: some View {
        VStack(spacing: 20) {
            Image(systemName: "film.stack")
                .font(.system(size: 80))
                .foregroundStyle(.secondary.opacity(0.5))
            Text("Nothing Here Yet")
                .font(.title2.bold())
                .foregroundStyle(.secondary)
            Text("Start watching content and it will appear here.")
                .font(.callout)
                .foregroundStyle(.tertiary)
        }
    }
}

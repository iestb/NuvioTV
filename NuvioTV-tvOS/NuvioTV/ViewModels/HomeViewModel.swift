import Foundation
import Combine

@MainActor
final class HomeViewModel: ObservableObject {

    struct CatalogSection: Identifiable {
        let id: String
        let title: String
        let addonName: String
        let items: [MetaPreview]
        let addon: Addon
        let catalog: CatalogDescriptor
    }

    @Published var sections: [CatalogSection] = []
    @Published var continueWatching: [WatchProgress] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var featuredItem: MetaPreview?

    private let addonStorage: AddonStorage
    private let watchProgressStorage: WatchProgressStorage
    private let addonService: AddonService

    init(
        addonStorage: AddonStorage = .shared,
        watchProgressStorage: WatchProgressStorage = .shared,
        addonService: AddonService = .shared
    ) {
        self.addonStorage = addonStorage
        self.watchProgressStorage = watchProgressStorage
        self.addonService = addonService
    }

    func loadContent() async {
        isLoading = true
        errorMessage = nil

        // Load continue watching
        continueWatching = watchProgressStorage.continueWatchingItems

        let catalogPairs = addonStorage.allCatalogs()

        if catalogPairs.isEmpty {
            isLoading = false
            return
        }

        var newSections: [CatalogSection] = []

        // Load first 8 catalogs concurrently
        let limitedPairs = Array(catalogPairs.prefix(8))

        await withTaskGroup(of: CatalogSection?.self) { group in
            for (addon, catalog) in limitedPairs {
                group.addTask {
                    do {
                        let items = try await self.addonService.fetchCatalog(addon: addon, catalog: catalog)
                        if items.isEmpty { return nil }
                        return CatalogSection(
                            id: "\(addon.id)/\(catalog.id)",
                            title: catalog.name,
                            addonName: addon.displayName,
                            items: items,
                            addon: addon,
                            catalog: catalog
                        )
                    } catch {
                        return nil
                    }
                }
            }

            for await section in group {
                if let section = section {
                    newSections.append(section)
                }
            }
        }

        // Sort to match original order
        sections = limitedPairs.compactMap { (addon, catalog) in
            newSections.first { $0.id == "\(addon.id)/\(catalog.id)" }
        }

        // Set featured item from first section
        featuredItem = sections.first?.items.first

        isLoading = false
    }

    func refresh() async {
        await loadContent()
    }
}

@MainActor
final class DetailViewModel: ObservableObject {
    @Published var meta: Meta?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedSeason: Int = 1
    @Published var episodes: [Video] = []

    private let addonService: AddonService
    private let addonStorage: AddonStorage

    init(addonService: AddonService = .shared, addonStorage: AddonStorage = .shared) {
        self.addonService = addonService
        self.addonStorage = addonStorage
    }

    func loadMeta(id: String, type: ContentType) async {
        isLoading = true
        errorMessage = nil

        // Find addons that support this meta type
        let supportingAddons = addonStorage.addons.filter { addon in
            addon.supportsMeta &&
            addon.types.contains(type.apiString)
        }

        // Try each addon until we get a result
        for addon in supportingAddons {
            do {
                let fetchedMeta = try await addonService.fetchMeta(addon: addon, type: type.apiString, id: id)
                self.meta = fetchedMeta
                updateEpisodes()
                isLoading = false
                return
            } catch {
                continue
            }
        }

        // If no addon returned meta, try all addons
        for addon in addonStorage.addons {
            do {
                let fetchedMeta = try await addonService.fetchMeta(addon: addon, type: type.apiString, id: id)
                self.meta = fetchedMeta
                updateEpisodes()
                isLoading = false
                return
            } catch {
                continue
            }
        }

        isLoading = false
        errorMessage = "Could not load content details. Make sure you have a compatible addon installed."
    }

    func selectSeason(_ season: Int) {
        selectedSeason = season
        updateEpisodes()
    }

    private func updateEpisodes() {
        guard let meta = meta else { return }
        if meta.isSeries {
            let seasonsInMeta = Set(meta.videos.compactMap { $0.season })
            if !seasonsInMeta.isEmpty && !seasonsInMeta.contains(selectedSeason) {
                selectedSeason = seasonsInMeta.min() ?? 1
            }
            episodes = meta.videos.filter { $0.season == selectedSeason }.sorted {
                ($0.episode ?? 0) < ($1.episode ?? 0)
            }
        }
    }

    var availableSeasons: [Int] {
        let seasons = Set(meta?.videos.compactMap { $0.season } ?? [])
        return seasons.sorted()
    }
}

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var query = ""
    @Published var results: [MetaPreview] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let addonService: AddonService
    private let addonStorage: AddonStorage
    private var searchTask: Task<Void, Never>?

    init(addonService: AddonService = .shared, addonStorage: AddonStorage = .shared) {
        self.addonService = addonService
        self.addonStorage = addonStorage
    }

    func search(_ query: String) {
        self.query = query
        searchTask?.cancel()

        guard !query.isEmpty else {
            results = []
            return
        }

        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce
            guard !Task.isCancelled else { return }
            await performSearch(query: query)
        }
    }

    private func performSearch(query: String) async {
        isLoading = true
        errorMessage = nil
        var allResults: [MetaPreview] = []

        let searchable = addonStorage.searchableCatalogs()

        await withTaskGroup(of: [MetaPreview].self) { group in
            for (addon, catalog) in searchable {
                group.addTask {
                    do {
                        return try await self.addonService.searchCatalog(addon: addon, catalog: catalog, query: query)
                    } catch {
                        return []
                    }
                }
            }

            for await items in group {
                allResults.append(contentsOf: items)
            }
        }

        // Deduplicate by id
        var seen = Set<String>()
        results = allResults.filter { seen.insert($0.id).inserted }
        isLoading = false
    }
}

@MainActor
final class StreamSelectionViewModel: ObservableObject {
    @Published var addonStreams: [AddonStreams] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let addonService: AddonService
    private let addonStorage: AddonStorage

    init(addonService: AddonService = .shared, addonStorage: AddonStorage = .shared) {
        self.addonService = addonService
        self.addonStorage = addonStorage
    }

    func loadStreams(type: String, id: String) async {
        isLoading = true
        errorMessage = nil
        addonStreams = []

        let results = await addonService.fetchAllStreams(
            addons: addonStorage.addons,
            type: type,
            id: id
        )

        addonStreams = results

        if results.isEmpty {
            errorMessage = "No streams found. Make sure you have a streaming addon installed."
        }

        isLoading = false
    }
}

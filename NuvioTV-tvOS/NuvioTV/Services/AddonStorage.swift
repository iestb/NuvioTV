import Foundation
import Combine

// MARK: - Addon Storage (persists installed addons)

final class AddonStorage: ObservableObject {
    static let shared = AddonStorage()

    @Published private(set) var addons: [Addon] = []

    private let storageKey = "installed_addons"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() {
        loadAddons()
    }

    var hasAddons: Bool { !addons.isEmpty }

    // MARK: - CRUD

    func addAddon(_ addon: Addon) {
        guard !addons.contains(where: { $0.id == addon.id }) else {
            updateAddon(addon)
            return
        }
        addons.append(addon)
        saveAddons()
    }

    func updateAddon(_ addon: Addon) {
        if let index = addons.firstIndex(where: { $0.id == addon.id }) {
            addons[index] = addon
            saveAddons()
        }
    }

    func removeAddon(id: String) {
        addons.removeAll { $0.id == id }
        saveAddons()
    }

    func reorderAddons(fromOffsets: IndexSet, toOffset: Int) {
        addons.move(fromOffsets: fromOffsets, toOffset: toOffset)
        saveAddons()
    }

    func containsAddon(id: String) -> Bool {
        addons.contains { $0.id == id }
    }

    // MARK: - Catalog filtering

    func addonsWithCatalogs(forType type: ContentType) -> [Addon] {
        addons.filter { addon in
            addon.catalogs.contains { $0.type == type.apiString }
        }
    }

    func allCatalogs() -> [(addon: Addon, catalog: CatalogDescriptor)] {
        addons.flatMap { addon in
            addon.catalogs.map { (addon: addon, catalog: $0) }
        }
    }

    func searchableCatalogs() -> [(addon: Addon, catalog: CatalogDescriptor)] {
        allCatalogs().filter { $0.catalog.supportsSearch }
    }

    // MARK: - Persistence

    private func saveAddons() {
        if let data = try? encoder.encode(addons) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func loadAddons() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let saved = try? decoder.decode([Addon].self, from: data) else {
            addons = []
            return
        }
        addons = saved
    }
}

// MARK: - Watch Progress Storage

final class WatchProgressStorage: ObservableObject {
    static let shared = WatchProgressStorage()

    @Published private(set) var progressItems: [WatchProgress] = []

    private let storageKey = "watch_progress"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() {
        loadProgress()
    }

    func updateProgress(
        id: String,
        contentType: ContentType,
        title: String,
        poster: String? = nil,
        backdrop: String? = nil,
        positionMs: Int64,
        durationMs: Int64,
        season: Int? = nil,
        episode: Int? = nil,
        episodeTitle: String? = nil,
        videoId: String? = nil
    ) {
        let progress = WatchProgress(
            id: id,
            contentType: contentType,
            title: title,
            poster: poster,
            backdrop: backdrop,
            positionMs: positionMs,
            durationMs: durationMs,
            season: season,
            episode: episode,
            episodeTitle: episodeTitle,
            lastWatchedAt: Date(),
            videoId: videoId
        )

        if let index = progressItems.firstIndex(where: { $0.id == id }) {
            progressItems[index] = progress
        } else {
            progressItems.insert(progress, at: 0)
        }

        // Keep only last 50 items
        if progressItems.count > 50 {
            progressItems = Array(progressItems.prefix(50))
        }

        saveProgress()
    }

    func getProgress(id: String) -> WatchProgress? {
        progressItems.first { $0.id == id }
    }

    func removeProgress(id: String) {
        progressItems.removeAll { $0.id == id }
        saveProgress()
    }

    func clearAll() {
        progressItems = []
        saveProgress()
    }

    var continueWatchingItems: [WatchProgress] {
        progressItems
            .filter { !$0.isFinished && $0.progressFraction > 0.02 }
            .sorted { $0.lastWatchedAt > $1.lastWatchedAt }
            .prefix(20)
            .map { $0 }
    }

    private func saveProgress() {
        if let data = try? encoder.encode(progressItems) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func loadProgress() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let saved = try? decoder.decode([WatchProgress].self, from: data) else {
            progressItems = []
            return
        }
        progressItems = saved
    }
}

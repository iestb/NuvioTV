import Foundation

// MARK: - Addon Service

@MainActor
final class AddonService: ObservableObject {
    static let shared = AddonService()

    private let session: URLSession
    private let decoder: JSONDecoder

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = true
        session = URLSession(configuration: config)
        decoder = JSONDecoder()
    }

    // MARK: - Manifest

    func fetchManifest(from urlString: String) async throws -> Addon {
        var manifestUrl = urlString
        if !manifestUrl.hasSuffix("/manifest.json") {
            if manifestUrl.hasSuffix("/") {
                manifestUrl += "manifest.json"
            } else {
                manifestUrl += "/manifest.json"
            }
        }

        guard let url = URL(string: manifestUrl) else {
            throw AddonError.invalidUrl(manifestUrl)
        }

        let data = try await fetch(url: url)
        let response = try decoder.decode(AddonManifestResponse.self, from: data)
        return mapManifest(response, baseUrl: extractBaseUrl(from: manifestUrl))
    }

    // MARK: - Catalog

    func fetchCatalog(addon: Addon, catalog: CatalogDescriptor, extra: [String: String] = [:]) async throws -> [MetaPreview] {
        guard let url = addon.catalogUrl(type: catalog.type, id: catalog.id, extra: extra) else {
            throw AddonError.invalidUrl("catalog/\(catalog.type)/\(catalog.id)")
        }

        let data = try await fetch(url: url)
        let response = try decoder.decode(CatalogResponse.self, from: data)
        return (response.metas ?? []).compactMap { mapMetaPreview($0) }
    }

    func searchCatalog(addon: Addon, catalog: CatalogDescriptor, query: String) async throws -> [MetaPreview] {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        return try await fetchCatalog(addon: addon, catalog: catalog, extra: ["search": encodedQuery])
    }

    // MARK: - Meta

    func fetchMeta(addon: Addon, type: String, id: String) async throws -> Meta {
        guard let url = addon.metaUrl(type: type, id: id) else {
            throw AddonError.invalidUrl("meta/\(type)/\(id)")
        }

        let data = try await fetch(url: url)
        let response = try decoder.decode(MetaDetailResponse.self, from: data)

        guard let metaResponse = response.meta else {
            throw AddonError.noData
        }

        return mapMetaFull(metaResponse, id: id, type: type)
    }

    // MARK: - Streams

    func fetchStreams(addon: Addon, type: String, id: String) async throws -> [Stream] {
        guard let url = addon.streamUrl(type: type, id: id) else {
            throw AddonError.invalidUrl("stream/\(type)/\(id)")
        }

        let data = try await fetch(url: url)
        let response = try decoder.decode(StreamsResponse.self, from: data)

        return (response.streams ?? []).map { mapStream($0, addonName: addon.displayName, addonLogo: addon.logo) }
    }

    func fetchAllStreams(addons: [Addon], type: String, id: String) async -> [AddonStreams] {
        let streamingAddons = addons.filter { $0.supportsStreams }
        var results: [AddonStreams] = []

        await withTaskGroup(of: AddonStreams?.self) { group in
            for addon in streamingAddons {
                let supportsType = addon.resources.first { $0.name == "stream" }?.types.contains(type) ?? true
                guard supportsType else { continue }

                group.addTask {
                    do {
                        let streams = try await self.fetchStreams(addon: addon, type: type, id: id)
                        if streams.isEmpty { return nil }
                        return AddonStreams(addonName: addon.displayName, addonLogo: addon.logo, streams: streams)
                    } catch {
                        return nil
                    }
                }
            }

            for await result in group {
                if let addonStreams = result {
                    results.append(addonStreams)
                }
            }
        }

        return results
    }

    // MARK: - Private helpers

    private func fetch(url: URL) async throws -> Data {
        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AddonError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw AddonError.httpError(httpResponse.statusCode)
        }

        return data
    }

    private func extractBaseUrl(from manifestUrl: String) -> String {
        if let range = manifestUrl.range(of: "/manifest.json") {
            return String(manifestUrl[..<range.lowerBound])
        }
        return manifestUrl
    }

    // MARK: - Mappers

    private func mapManifest(_ response: AddonManifestResponse, baseUrl: String) -> Addon {
        let catalogs = (response.catalogs ?? []).map { cat in
            CatalogDescriptor(
                id: cat.id,
                type: cat.type,
                name: cat.name,
                extra: (cat.extra ?? []).map {
                    CatalogExtra(
                        name: $0.name,
                        isRequired: $0.isRequired ?? false,
                        options: $0.options,
                        defaultValue: $0.defaultValue
                    )
                },
                extraSupported: cat.extraSupported ?? [],
                extraRequired: cat.extraRequired ?? []
            )
        }

        let resources = (response.resources ?? []).map { res in
            AddonResource(
                name: res.name ?? "",
                types: res.types ?? [],
                idPrefixes: res.idPrefixes
            )
        }

        let behaviorHints = response.behaviorHints.map { hints in
            AddonBehaviorHints(
                configurable: hints.configurable,
                configurationRequired: hints.configurationRequired,
                newEpisodeNotifications: hints.newEpisodeNotifications
            )
        }

        return Addon(
            id: response.id,
            name: response.name,
            version: response.version,
            description: response.description,
            logo: response.logo,
            background: response.background,
            baseUrl: baseUrl,
            catalogs: catalogs,
            types: response.types ?? [],
            resources: resources,
            idPrefixes: response.idPrefixes ?? [],
            behaviorHints: behaviorHints
        )
    }

    private func mapMetaPreview(_ response: MetaPreviewResponse) -> MetaPreview? {
        guard let id = response.id, let name = response.name else { return nil }
        return MetaPreview(
            id: id,
            type: ContentType(rawValue: response.type ?? "movie"),
            name: name,
            poster: response.poster,
            background: response.background,
            logo: response.logo,
            releaseInfo: response.releaseInfo,
            imdbRating: response.imdbRatingFloat,
            genres: response.genres ?? [],
            description: response.description
        )
    }

    private func mapMetaFull(_ response: MetaFullResponse, id: String, type: String) -> Meta {
        let videos = (response.videos ?? []).compactMap { v -> Video? in
            guard let vid = v.id else { return nil }
            return Video(
                id: vid,
                title: v.title ?? "",
                released: v.released,
                thumbnail: v.thumbnail,
                season: v.season,
                episode: v.episode,
                overview: v.overview,
                runtime: v.runtime,
                available: v.available
            )
        }

        let links = (response.links ?? []).compactMap { l -> MetaLink? in
            guard let name = l.name, let category = l.category, let url = l.url else { return nil }
            return MetaLink(name: name, category: category, url: url)
        }

        return Meta(
            id: response.id ?? id,
            type: ContentType(rawValue: response.type ?? type),
            name: response.name ?? "",
            poster: response.poster,
            background: response.background,
            logo: response.logo,
            description: response.description,
            releaseInfo: response.releaseInfo,
            status: response.status,
            imdbRating: Float(response.imdbRating ?? ""),
            genres: response.genres ?? [],
            runtime: response.runtime,
            director: response.director ?? [],
            cast: response.cast ?? [],
            castMembers: [],
            videos: videos,
            imdbId: response.imdbId,
            trailerYtIds: response.trailerYtIds ?? [],
            ageRating: response.ageRating,
            country: response.country,
            links: links,
            behaviorHints: response.behaviorHints.map {
                MetaBehaviorHints(
                    defaultVideoId: $0.defaultVideoId,
                    hasScheduledVideos: $0.hasScheduledVideos
                )
            }
        )
    }

    private func mapStream(_ response: StreamResponse, addonName: String, addonLogo: String?) -> Stream {
        let behaviorHints = response.behaviorHints.map { hints in
            StreamBehaviorHints(
                notWebReady: hints.notWebReady,
                bingeGroup: hints.bingeGroup,
                countryWhitelist: hints.countryWhitelist,
                proxyHeaders: hints.proxyHeaders.map {
                    ProxyHeaders(request: $0.request, response: $0.response)
                },
                videoHash: hints.videoHash,
                videoSize: hints.videoSize,
                filename: hints.filename
            )
        }

        return Stream(
            name: response.name,
            title: response.title,
            description: response.description,
            url: response.url,
            ytId: response.ytId,
            infoHash: response.infoHash,
            fileIdx: response.fileIdx,
            externalUrl: response.externalUrl,
            behaviorHints: behaviorHints,
            addonName: addonName,
            addonLogo: addonLogo
        )
    }
}

// MARK: - Errors

enum AddonError: LocalizedError {
    case invalidUrl(String)
    case invalidResponse
    case noData
    case httpError(Int)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidUrl(let url): return "Invalid URL: \(url)"
        case .invalidResponse: return "Invalid server response"
        case .noData: return "No data received"
        case .httpError(let code): return "Server error: \(code)"
        case .decodingError(let error): return "Failed to parse response: \(error.localizedDescription)"
        }
    }
}

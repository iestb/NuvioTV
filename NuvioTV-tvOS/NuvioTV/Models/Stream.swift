import Foundation

struct Stream: Identifiable, Codable, Equatable {
    let id: UUID
    let name: String?
    let title: String?
    let description: String?
    let url: String?
    let ytId: String?
    let infoHash: String?
    let fileIdx: Int?
    let externalUrl: String?
    let behaviorHints: StreamBehaviorHints?
    let addonName: String
    let addonLogo: String?

    init(
        id: UUID = UUID(),
        name: String? = nil,
        title: String? = nil,
        description: String? = nil,
        url: String? = nil,
        ytId: String? = nil,
        infoHash: String? = nil,
        fileIdx: Int? = nil,
        externalUrl: String? = nil,
        behaviorHints: StreamBehaviorHints? = nil,
        addonName: String,
        addonLogo: String? = nil
    ) {
        self.id = id
        self.name = name
        self.title = title
        self.description = description
        self.url = url
        self.ytId = ytId
        self.infoHash = infoHash
        self.fileIdx = fileIdx
        self.externalUrl = externalUrl
        self.behaviorHints = behaviorHints
        self.addonName = addonName
        self.addonLogo = addonLogo
    }

    var streamUrl: String? { url ?? externalUrl }

    var isTorrent: Bool { infoHash != nil }
    var isYouTube: Bool { ytId != nil }
    var isExternal: Bool { externalUrl != nil && url == nil }

    var displayName: String {
        name ?? title ?? description ?? "Unknown Stream"
    }

    var displayDescription: String? {
        description ?? title
    }

    var qualityBadge: String? {
        let combined = [name, title, description].compactMap { $0 }.joined(separator: " ").uppercased()
        if combined.contains("4K") || combined.contains("UHD") || combined.contains("2160") {
            return "4K"
        } else if combined.contains("1080") {
            return "HD"
        } else if combined.contains("720") {
            return "HD"
        }
        return nil
    }
}

struct StreamBehaviorHints: Codable, Equatable {
    let notWebReady: Bool?
    let bingeGroup: String?
    let countryWhitelist: [String]?
    let proxyHeaders: ProxyHeaders?
    let videoHash: String?
    let videoSize: Int64?
    let filename: String?
}

struct ProxyHeaders: Codable, Equatable {
    let request: [String: String]?
    let response: [String: String]?
}

struct AddonStreams: Identifiable {
    let id: UUID = UUID()
    let addonName: String
    let addonLogo: String?
    let streams: [Stream]
}

// MARK: - API Response DTOs

struct AddonManifestResponse: Codable {
    let id: String
    let name: String
    let version: String
    let description: String?
    let logo: String?
    let background: String?
    let catalogs: [CatalogDescriptorResponse]?
    let resources: [ResourceResponse]?
    let types: [String]?
    let idPrefixes: [String]?
    let behaviorHints: BehaviorHintsResponse?

    enum CodingKeys: String, CodingKey {
        case id, name, version, description, logo, background
        case catalogs, resources, types, idPrefixes, behaviorHints
    }
}

struct CatalogDescriptorResponse: Codable {
    let id: String
    let type: String
    let name: String
    let extra: [ExtraResponse]?
    let extraSupported: [String]?
    let extraRequired: [String]?
}

struct ExtraResponse: Codable {
    let name: String
    let isRequired: Bool?
    let options: [String]?
    let defaultValue: String?
}

struct ResourceResponse: Codable {
    let name: String?
    let types: [String]?
    let idPrefixes: [String]?

    init(from decoder: Decoder) throws {
        if let container = try? decoder.singleValueContainer(),
           let str = try? container.decode(String.self) {
            name = str
            types = nil
            idPrefixes = nil
        } else {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            name = try? container.decodeIfPresent(String.self, forKey: .name)
            types = try? container.decodeIfPresent([String].self, forKey: .types)
            idPrefixes = try? container.decodeIfPresent([String].self, forKey: .idPrefixes)
        }
    }

    enum CodingKeys: String, CodingKey {
        case name, types, idPrefixes
    }
}

struct BehaviorHintsResponse: Codable {
    let configurable: Bool?
    let configurationRequired: Bool?
    let newEpisodeNotifications: Bool?
}

struct CatalogResponse: Codable {
    let metas: [MetaPreviewResponse]?
}

struct MetaPreviewResponse: Codable {
    let id: String?
    let type: String?
    let name: String?
    let poster: String?
    let background: String?
    let logo: String?
    let releaseInfo: String?
    let imdbRating: String?
    let genres: [String]?
    let description: String?

    var imdbRatingFloat: Float? {
        guard let rating = imdbRating else { return nil }
        return Float(rating)
    }
}

struct MetaDetailResponse: Codable {
    let meta: MetaFullResponse?
}

struct MetaFullResponse: Codable {
    let id: String?
    let type: String?
    let name: String?
    let poster: String?
    let background: String?
    let logo: String?
    let description: String?
    let releaseInfo: String?
    let status: String?
    let imdbRating: String?
    let genres: [String]?
    let runtime: String?
    let director: [String]?
    let cast: [String]?
    let videos: [VideoResponse]?
    let imdbId: String?
    let trailerYtIds: [String]?
    let ageRating: String?
    let country: String?
    let links: [LinkResponse]?
    let behaviorHints: MetaBehaviorHintsResponse?
}

struct VideoResponse: Codable {
    let id: String?
    let title: String?
    let released: String?
    let thumbnail: String?
    let season: Int?
    let episode: Int?
    let overview: String?
    let runtime: Int?
    let available: Bool?
}

struct LinkResponse: Codable {
    let name: String?
    let category: String?
    let url: String?
}

struct MetaBehaviorHintsResponse: Codable {
    let defaultVideoId: String?
    let hasScheduledVideos: Bool?
}

struct StreamsResponse: Codable {
    let streams: [StreamResponse]?
}

struct StreamResponse: Codable {
    let name: String?
    let title: String?
    let description: String?
    let url: String?
    let ytId: String?
    let infoHash: String?
    let fileIdx: Int?
    let externalUrl: String?
    let behaviorHints: StreamBehaviorHintsResponse?
}

struct StreamBehaviorHintsResponse: Codable {
    let notWebReady: Bool?
    let bingeGroup: String?
    let countryWhitelist: [String]?
    let proxyHeaders: ProxyHeadersResponse?
    let videoHash: String?
    let videoSize: Int64?
    let filename: String?
}

struct ProxyHeadersResponse: Codable {
    let request: [String: String]?
    let response: [String: String]?
}

import Foundation

struct Meta: Identifiable, Codable, Equatable {
    let id: String
    let type: ContentType
    let name: String
    let poster: String?
    let background: String?
    let logo: String?
    let description: String?
    let releaseInfo: String?
    let status: String?
    let imdbRating: Float?
    let genres: [String]
    let runtime: String?
    let director: [String]
    let cast: [String]
    let castMembers: [MetaCastMember]
    let videos: [Video]
    let imdbId: String?
    let trailerYtIds: [String]
    let ageRating: String?
    let country: String?
    let links: [MetaLink]
    let behaviorHints: MetaBehaviorHints?

    var backdropUrl: String? {
        background ?? poster
    }

    var displayYear: String {
        releaseInfo ?? ""
    }

    var isMovie: Bool { type == .movie }
    var isSeries: Bool { type == .series }

    var formattedGenres: String {
        genres.prefix(3).joined(separator: " • ")
    }

    var ratingString: String? {
        guard let rating = imdbRating else { return nil }
        return String(format: "%.1f", rating)
    }
}

struct MetaCastMember: Codable, Equatable {
    let name: String
    let character: String?
    let photo: String?
    let tmdbId: Int?
}

struct Video: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let released: String?
    let thumbnail: String?
    let season: Int?
    let episode: Int?
    let overview: String?
    let runtime: Int?
    let available: Bool?

    var isEpisode: Bool { season != nil && episode != nil }

    var episodeLabel: String {
        guard let s = season, let e = episode else { return title }
        return "S\(String(format: "%02d", s))E\(String(format: "%02d", e))"
    }
}

struct MetaLink: Codable, Equatable {
    let name: String
    let category: String
    let url: String
}

struct MetaBehaviorHints: Codable, Equatable {
    let defaultVideoId: String?
    let hasScheduledVideos: Bool?
}

// MARK: - Preview meta item for catalog rows
struct MetaPreview: Identifiable, Codable, Equatable {
    let id: String
    let type: ContentType
    let name: String
    let poster: String?
    let background: String?
    let logo: String?
    let releaseInfo: String?
    let imdbRating: Float?
    let genres: [String]
    let description: String?

    var ratingString: String? {
        guard let rating = imdbRating else { return nil }
        return String(format: "%.1f", rating)
    }
}

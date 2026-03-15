import Foundation

enum ContentType: String, Codable, CaseIterable {
    case movie = "movie"
    case series = "series"
    case channel = "channel"
    case tv = "tv"
    case unknown = "unknown"

    init(rawValue: String) {
        switch rawValue.trimmingCharacters(in: .whitespaces).lowercased() {
        case "movie": self = .movie
        case "series": self = .series
        case "channel": self = .channel
        case "tv": self = .tv
        default: self = .unknown
        }
    }

    var apiString: String {
        switch self {
        case .movie: return "movie"
        case .series: return "series"
        case .channel: return "channel"
        case .tv: return "tv"
        case .unknown: return "movie"
        }
    }

    var displayName: String {
        switch self {
        case .movie: return "Movies"
        case .series: return "Series"
        case .channel: return "Channels"
        case .tv: return "TV"
        case .unknown: return "Content"
        }
    }
}

import Foundation

struct WatchProgress: Identifiable, Codable {
    let id: String          // contentId (imdbId or similar)
    let contentType: ContentType
    let title: String
    let poster: String?
    let backdrop: String?
    let positionMs: Int64
    let durationMs: Int64
    let season: Int?
    let episode: Int?
    let episodeTitle: String?
    let lastWatchedAt: Date
    let videoId: String?    // for series episodes

    var progressFraction: Double {
        guard durationMs > 0 else { return 0 }
        return Double(positionMs) / Double(durationMs)
    }

    var isFinished: Bool {
        progressFraction > 0.9
    }

    var remainingSeconds: Int {
        let remaining = durationMs - positionMs
        return Int(remaining / 1000)
    }

    var displayLabel: String {
        if let s = season, let e = episode {
            return "S\(String(format: "%02d", s))E\(String(format: "%02d", e))"
        }
        return title
    }
}

struct WatchedItem: Identifiable, Codable {
    let id: String
    let contentType: ContentType
    let title: String
    let poster: String?
    let watchedAt: Date
}

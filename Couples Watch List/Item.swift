import Foundation
import SwiftData

enum WatchStatus: String, Codable, CaseIterable {
    case wantToWatch = "Want to Watch"
    case watching = "Watching"
    case watched = "Watched"
}

enum MediaType: String, Codable, CaseIterable {
    case movie
    case tv

    var displayName: String {
        switch self {
        case .movie: "Movie"
        case .tv: "TV Show"
        }
    }

    var systemImage: String {
        switch self {
        case .movie: "film"
        case .tv: "tv"
        }
    }
}

@Model
final class SeasonProgress {
    var seasonNumber: Int
    var episodeCount: Int
    var name: String
    var statusRaw: String
    var currentEpisode: Int
    var watchedEpisodes: [Int] = []
    var item: WatchlistItem?

    init(seasonNumber: Int, episodeCount: Int, name: String) {
        self.seasonNumber = seasonNumber
        self.episodeCount = episodeCount
        self.name = name
        self.statusRaw = WatchStatus.wantToWatch.rawValue
        self.currentEpisode = 1
    }

    var status: WatchStatus {
        get { WatchStatus(rawValue: statusRaw) ?? .wantToWatch }
        set { statusRaw = newValue.rawValue }
    }
}

@Model
final class WatchlistItem {
    var tmdbID: Int
    var mediaTypeRaw: String
    var title: String
    var posterPath: String?
    var overview: String
    var releaseYear: String
    var statusRaw: String
    var addedAt: Date
    var numberOfSeasons: Int?
    var numberOfEpisodes: Int?
    @Relationship(deleteRule: .cascade) var seasonProgresses: [SeasonProgress] = []

    init(
        tmdbID: Int,
        mediaType: MediaType,
        title: String,
        posterPath: String? = nil,
        overview: String,
        releaseYear: String,
        status: WatchStatus = .wantToWatch,
        numberOfSeasons: Int? = nil,
        numberOfEpisodes: Int? = nil
    ) {
        self.tmdbID = tmdbID
        self.mediaTypeRaw = mediaType.rawValue
        self.title = title
        self.posterPath = posterPath
        self.overview = overview
        self.releaseYear = releaseYear
        self.statusRaw = status.rawValue
        self.addedAt = Date()
        self.numberOfSeasons = numberOfSeasons
        self.numberOfEpisodes = numberOfEpisodes
    }

    var mediaType: MediaType {
        get { MediaType(rawValue: mediaTypeRaw) ?? .movie }
        set { mediaTypeRaw = newValue.rawValue }
    }

    var status: WatchStatus {
        get { WatchStatus(rawValue: statusRaw) ?? .wantToWatch }
        set { statusRaw = newValue.rawValue }
    }

    var posterURL: URL? {
        guard let path = posterPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w500\(path)")
    }

    /// Derived from season-level statuses when available; falls back to the stored status for movies.
    var derivedStatus: WatchStatus {
        guard !seasonProgresses.isEmpty else { return status }
        if seasonProgresses.contains(where: { $0.status == .watching }) { return .watching }
        if seasonProgresses.allSatisfy({ $0.status == .watched }) { return .watched }
        return .wantToWatch
    }
}

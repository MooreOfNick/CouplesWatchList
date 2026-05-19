import Foundation

struct TMDBSearchResponse: Codable {
    let results: [TMDBSearchResult]
}

struct TMDBSearchResult: Codable, Identifiable {
    let id: Int
    let mediaType: String?
    let title: String?
    let name: String?
    let posterPath: String?
    let overview: String?
    let releaseDate: String?
    let firstAirDate: String?

    enum CodingKeys: String, CodingKey {
        case id
        case mediaType = "media_type"
        case title
        case name
        case posterPath = "poster_path"
        case overview
        case releaseDate = "release_date"
        case firstAirDate = "first_air_date"
    }

    var displayTitle: String { title ?? name ?? "Unknown" }

    var releaseYear: String {
        let dateStr = releaseDate ?? firstAirDate ?? ""
        return String(dateStr.prefix(4))
    }

    var resolvedMediaType: MediaType? {
        guard let mediaType else { return nil }
        return MediaType(rawValue: mediaType)
    }

    var posterURL: URL? {
        guard let path = posterPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w500\(path)")
    }
}

struct TMDBTVDetails: Codable {
    let numberOfSeasons: Int
    let numberOfEpisodes: Int
    let seasons: [TMDBSeason]

    enum CodingKeys: String, CodingKey {
        case numberOfSeasons = "number_of_seasons"
        case numberOfEpisodes = "number_of_episodes"
        case seasons
    }
}

struct TMDBSeason: Codable, Identifiable {
    let id: Int
    let seasonNumber: Int
    let episodeCount: Int
    let name: String

    enum CodingKeys: String, CodingKey {
        case id
        case seasonNumber = "season_number"
        case episodeCount = "episode_count"
        case name
    }
}

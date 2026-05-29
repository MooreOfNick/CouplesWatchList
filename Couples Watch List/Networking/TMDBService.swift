import Foundation

actor TMDBService {
    static let shared = TMDBService()

    private let apiKey: String?
    private let baseURL = "https://api.themoviedb.org/3"

    private init() {
        guard
            let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
            let dict = NSDictionary(contentsOfFile: path),
            let key = dict["TMDB_API_KEY"] as? String,
            key != "YOUR_API_KEY_HERE",
            !key.isEmpty
        else {
            apiKey = nil
            return
        }
        apiKey = key
    }

    enum TMDBError: LocalizedError {
        case missingAPIKey
        case badResponse(Int)

        var errorDescription: String? {
            switch self {
            case .missingAPIKey:
                return "TMDB API key not configured. Add it to Secrets.plist."
            case .badResponse(let code):
                return "Unexpected response from TMDB (HTTP \(code))."
            }
        }
    }

    func searchMulti(query: String) async throws -> [TMDBSearchResult] {
        guard let apiKey else { throw TMDBError.missingAPIKey }
        guard !query.isEmpty else { return [] }

        var components = URLComponents(string: "\(baseURL)/search/multi")!
        components.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "include_adult", value: "false"),
        ]

        let (data, response) = try await URLSession.shared.data(from: components.url!)

        guard let http = response as? HTTPURLResponse else { throw TMDBError.badResponse(0) }
        guard http.statusCode == 200 else { throw TMDBError.badResponse(http.statusCode) }

        let decoded = try JSONDecoder().decode(TMDBSearchResponse.self, from: data)
        return decoded.results.filter { $0.mediaType == "movie" || $0.mediaType == "tv" }
    }

    func fetchTrending() async throws -> [TMDBSearchResult] {
        guard let apiKey else { throw TMDBError.missingAPIKey }

        var components = URLComponents(string: "\(baseURL)/trending/all/week")!
        components.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "include_adult", value: "false"),
        ]

        let (data, response) = try await URLSession.shared.data(from: components.url!)

        guard let http = response as? HTTPURLResponse else { throw TMDBError.badResponse(0) }
        guard http.statusCode == 200 else { throw TMDBError.badResponse(http.statusCode) }

        let decoded = try JSONDecoder().decode(TMDBSearchResponse.self, from: data)
        return decoded.results.filter { $0.mediaType == "movie" || $0.mediaType == "tv" }
    }

    func fetchSeasonDetails(showID: Int, seasonNumber: Int) async throws -> TMDBSeasonDetails {
        guard let apiKey else { throw TMDBError.missingAPIKey }

        var components = URLComponents(string: "\(baseURL)/tv/\(showID)/season/\(seasonNumber)")!
        components.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey)
        ]

        let (data, response) = try await URLSession.shared.data(from: components.url!)

        guard let http = response as? HTTPURLResponse else { throw TMDBError.badResponse(0) }
        guard http.statusCode == 200 else { throw TMDBError.badResponse(http.statusCode) }

        return try JSONDecoder().decode(TMDBSeasonDetails.self, from: data)
    }

    func fetchRecommendations(seeds: [(id: Int, mediaType: MediaType)]) async -> [TMDBSearchResult] {
        guard !seeds.isEmpty else { return [] }
        var all: [TMDBSearchResult] = []
        await withTaskGroup(of: [TMDBSearchResult].self) { group in
            for seed in seeds {
                group.addTask {
                    (try? await self.fetchRecsForSeed(id: seed.id, mediaType: seed.mediaType)) ?? []
                }
            }
            for await batch in group {
                all.append(contentsOf: batch)
            }
        }
        var seen = Set<Int>()
        return all.filter { seen.insert($0.id).inserted }
    }

    private func fetchRecsForSeed(id: Int, mediaType: MediaType) async throws -> [TMDBSearchResult] {
        guard let apiKey else { throw TMDBError.missingAPIKey }
        let segment = mediaType == .movie ? "movie" : "tv"
        var components = URLComponents(string: "\(baseURL)/\(segment)/\(id)/recommendations")!
        components.queryItems = [URLQueryItem(name: "api_key", value: apiKey)]

        let (data, response) = try await URLSession.shared.data(from: components.url!)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return [] }

        let decoded = try JSONDecoder().decode(TMDBRecommendResponse.self, from: data)
        return decoded.results.map {
            TMDBSearchResult(
                id: $0.id,
                mediaType: mediaType.rawValue,
                title: $0.title,
                name: $0.name,
                posterPath: $0.posterPath,
                overview: $0.overview,
                releaseDate: $0.releaseDate,
                firstAirDate: $0.firstAirDate
            )
        }
    }

    func fetchWatchProviders(showID: Int) async throws -> [TMDBWatchProvider] {
        guard let apiKey else { throw TMDBError.missingAPIKey }

        var components = URLComponents(string: "\(baseURL)/tv/\(showID)/watch/providers")!
        components.queryItems = [URLQueryItem(name: "api_key", value: apiKey)]

        let (data, response) = try await URLSession.shared.data(from: components.url!)

        guard let http = response as? HTTPURLResponse else { throw TMDBError.badResponse(0) }
        guard http.statusCode == 200 else { throw TMDBError.badResponse(http.statusCode) }

        let decoded = try JSONDecoder().decode(TMDBWatchProvidersResponse.self, from: data)
        let region = Locale.current.region?.identifier ?? "US"
        let regionData = decoded.results[region] ?? decoded.results["US"]

        let all = (regionData?.flatrate ?? []) + (regionData?.free ?? []) + (regionData?.ads ?? [])
        var seen = Set<Int>()
        return all.filter { seen.insert($0.providerId).inserted }
    }

    func fetchTVDetails(id: Int) async throws -> TMDBTVDetails {
        guard let apiKey else { throw TMDBError.missingAPIKey }

        var components = URLComponents(string: "\(baseURL)/tv/\(id)")!
        components.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey)
        ]

        let (data, response) = try await URLSession.shared.data(from: components.url!)

        guard let http = response as? HTTPURLResponse else { throw TMDBError.badResponse(0) }
        guard http.statusCode == 200 else { throw TMDBError.badResponse(http.statusCode) }

        return try JSONDecoder().decode(TMDBTVDetails.self, from: data)
    }
}

private struct TMDBRecommendResponse: Codable {
    let results: [Item]

    struct Item: Codable {
        let id: Int
        let title: String?
        let name: String?
        let posterPath: String?
        let overview: String?
        let releaseDate: String?
        let firstAirDate: String?

        enum CodingKeys: String, CodingKey {
            case id, title, name, overview
            case posterPath = "poster_path"
            case releaseDate = "release_date"
            case firstAirDate = "first_air_date"
        }
    }
}

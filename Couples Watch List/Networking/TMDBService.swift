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

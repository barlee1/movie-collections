//
//  TMDBClient.swift
//  MovieCollection
//
//  Purpose: Live movie search and details from The Movie Database (TMDB) API,
//  so the add form, cover scanner, and spreadsheet import can find any movie,
//  not just the 200 bundled ones. Also where a movie can be bought, for the
//  detail screen's "Own it instead" card. The key lives in Secrets.plist (not in git);
//  without it the app quietly uses only the bundled catalog.
//  Used in: AppViewModel.
//
//  Required credit (shown on Profile › About):
//  "This product uses the TMDB API but is not endorsed or certified by TMDB."
//  Where-to-buy data comes from JustWatch through TMDB, which must be credited
//  wherever it's shown (see AppInfo.justWatchCredit).
//

import Foundation

/// A source of movies beyond the bundled catalog. TMDBClient in the app, a fake in tests.
nonisolated protocol RemoteMovieCatalog: Sendable {
    /// Movies whose title matches the search. Results are summaries
    /// (`isSummary == true`): no director, cast, runtime, or film rating yet.
    func searchMovies(_ query: String, year: Int?) async throws -> [Movie]
    /// One movie with every detail filled in.
    func movieDetails(id: Int) async throws -> Movie
    /// Stores that sell the movie in a country (an ISO code like "US").
    /// Nil if the source doesn't know.
    func purchaseOptions(movieID: Int, region: String) async throws -> PurchaseOptions?
}

extension RemoteMovieCatalog {
    /// Catalogs without where-to-buy data (like test fakes) don't know.
    func purchaseOptions(movieID: Int, region: String) async throws -> PurchaseOptions? { nil }
}

nonisolated struct TMDBClient: RemoteMovieCatalog {

    enum Credential: Sendable, Equatable {
        /// The long "API Read Access Token", sent as a bearer token.
        case readAccessToken(String)
        /// The short v3 "API Key", sent as a query parameter.
        case apiKey(String)
    }

    enum TMDBError: LocalizedError {
        case badResponse(Int)

        var errorDescription: String? {
            switch self {
            case .badResponse(let status): "The movie database didn't respond (error \(status))."
            }
        }
    }

    let credential: Credential
    private let session: URLSession
    private static let baseURL = URL(string: "https://api.themoviedb.org/3/")!

    init(credential: Credential, session: URLSession = .shared) {
        self.credential = credential
        self.session = session
    }

    /// A client using the key in Secrets.plist, or nil if there isn't one.
    /// Secrets.plist holds `TMDBReadAccessToken` (preferred) or `TMDBAPIKey`.
    static func fromBundle(_ bundle: Bundle = .main) -> TMDBClient? {
        guard let url = bundle.url(forResource: "Secrets", withExtension: "plist"),
            let data = try? Data(contentsOf: url),
            let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { return nil }
        if let token = (plist["TMDBReadAccessToken"] as? String)?.trimmed, !token.isEmpty {
            return TMDBClient(credential: .readAccessToken(token))
        }
        if let key = (plist["TMDBAPIKey"] as? String)?.trimmed, !key.isEmpty {
            return TMDBClient(credential: .apiKey(key))
        }
        return nil
    }

    // MARK: - Requests

    func searchMovies(_ query: String, year: Int?) async throws -> [Movie] {
        var items = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "include_adult", value: "false"),
            URLQueryItem(name: "language", value: "en-US"),
        ]
        if let year { items.append(URLQueryItem(name: "year", value: String(year))) }
        let data = try await get("search/movie", items)
        return try Self.parseSearch(data)
    }

    func movieDetails(id: Int) async throws -> Movie {
        let data = try await get(
            "movie/\(id)",
            [
                URLQueryItem(name: "append_to_response", value: "credits,release_dates"),
                URLQueryItem(name: "language", value: "en-US"),
            ])
        return try Self.parseDetails(data)
    }

    func purchaseOptions(movieID: Int, region: String) async throws -> PurchaseOptions? {
        let data = try await get("movie/\(movieID)/watch/providers", [])
        return try Self.parsePurchaseOptions(data, region: region)
    }

    /// Builds the request for a TMDB path. Separate from `get` so tests can check it.
    func request(_ path: String, _ queryItems: [URLQueryItem]) -> URLRequest {
        var components = URLComponents(url: Self.baseURL.appending(path: path), resolvingAgainstBaseURL: false)
        var items = queryItems
        if case .apiKey(let key) = credential {
            items.append(URLQueryItem(name: "api_key", value: key))
        }
        components?.queryItems = items
        var request = URLRequest(url: components?.url ?? Self.baseURL)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if case .readAccessToken(let token) = credential {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.timeoutInterval = 15
        return request
    }

    private func get(_ path: String, _ queryItems: [URLQueryItem]) async throws -> Data {
        let (data, response) = try await session.data(for: request(path, queryItems))
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else { throw TMDBError.badResponse(status) }
        return data
    }

    // MARK: - Parsing

    private struct SearchResponse: Decodable {
        struct Result: Decodable {
            let id: Int
            let title: String
            let overview: String?
            let releaseDate: String?
            let genreIds: [Int]?
        }
        let results: [Result]
    }

    private struct DetailsResponse: Decodable {
        struct Genre: Decodable { let name: String }
        struct Credits: Decodable {
            struct Cast: Decodable { let name: String; let order: Int? }
            struct Crew: Decodable { let name: String; let job: String? }
            let cast: [Cast]
            let crew: [Crew]
        }
        struct ReleaseDates: Decodable {
            struct Country: Decodable {
                struct Release: Decodable { let certification: String?; let type: Int? }
                let iso31661: String
                let releaseDates: [Release]
            }
            let results: [Country]
        }
        let id: Int
        let imdbId: String?
        let title: String
        let overview: String?
        let releaseDate: String?
        let runtime: Int?
        let genres: [Genre]?
        let credits: Credits?
        let releaseDates: ReleaseDates?
    }

    private struct ProvidersResponse: Decodable {
        struct Country: Decodable {
            struct Provider: Decodable {
                let providerId: Int
                let providerName: String
                let displayPriority: Int?
            }
            let link: String?
            let buy: [Provider]?
        }
        let results: [String: Country]
    }

    /// TMDB's JSON uses snake_case keys like `release_date`.
    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }

    /// How many cast members to keep, matching the bundled catalog.
    static let castLimit = 5

    static func parseSearch(_ data: Data) throws -> [Movie] {
        try decoder.decode(SearchResponse.self, from: data).results.map { result in
            Movie(
                id: result.id,
                imdbID: nil,
                title: result.title,
                genres: (result.genreIds ?? []).compactMap { genreNames[$0] },
                overview: result.overview ?? "",
                year: year(from: result.releaseDate),
                runtime: nil,
                director: "",
                cast: [],
                filmRating: nil,
                isSummary: true
            )
        }
    }

    static func parseDetails(_ data: Data) throws -> Movie {
        let details = try decoder.decode(DetailsResponse.self, from: data)
        let credits = details.credits
        let directors = (credits?.crew ?? []).filter { $0.job == "Director" }.map(\.name)
        let cast = (credits?.cast ?? [])
            .sorted { ($0.order ?? .max) < ($1.order ?? .max) }
            .prefix(castLimit)
            .map(\.name)
        return Movie(
            id: details.id,
            imdbID: details.imdbId.flatMap { $0.isEmpty ? nil : $0 },
            title: details.title,
            genres: (details.genres ?? []).map(\.name),
            overview: details.overview ?? "",
            year: year(from: details.releaseDate),
            runtime: details.runtime.flatMap { $0 > 0 ? $0 : nil },
            director: directors.joined(separator: ", "),
            cast: Array(cast),
            filmRating: usCertification(details.releaseDates)
        )
    }

    /// Where the movie is sold in one country. A country with no listing at
    /// all means it isn't sold or streamed there, so it can't be bought.
    static func parsePurchaseOptions(_ data: Data, region: String) throws -> PurchaseOptions {
        let country = try decoder.decode(ProvidersResponse.self, from: data).results[region.uppercased()]
        let stores = (country?.buy ?? [])
            .sorted { ($0.displayPriority ?? .max) < ($1.displayPriority ?? .max) }
            .map { PurchaseOptions.Store(id: $0.providerId, name: $0.providerName) }
        return PurchaseOptions(stores: stores, region: region.uppercased(), watchPageURL: country?.link.flatMap(URL.init(string:)))
    }

    /// The US rating, preferring the theatrical release (type 3) over others.
    private static func usCertification(_ releaseDates: DetailsResponse.ReleaseDates?) -> FilmRating? {
        guard let us = releaseDates?.results.first(where: { $0.iso31661 == "US" }) else { return nil }
        let rated = us.releaseDates.filter { !($0.certification ?? "").trimmed.isEmpty }
        let best = rated.first { $0.type == 3 } ?? rated.first
        return best?.certification.flatMap { FilmRating(rawValue: $0.trimmed.uppercased()) }
    }

    /// The year from a "yyyy-MM-dd" date.
    private static func year(from date: String?) -> Int? {
        date.flatMap { Int($0.prefix(4)) }
    }

    /// TMDB's movie genre IDs, used to name genres in search results.
    static let genreNames: [Int: String] = [
        28: "Action", 12: "Adventure", 16: "Animation", 35: "Comedy", 80: "Crime",
        99: "Documentary", 18: "Drama", 10751: "Family", 14: "Fantasy", 36: "History",
        27: "Horror", 10402: "Music", 9648: "Mystery", 10749: "Romance",
        878: "Science Fiction", 10770: "TV Movie", 53: "Thriller", 10752: "War", 37: "Western",
    ]
}

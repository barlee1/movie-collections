//
//  Movie.swift
//  MovieCollection
//
//  Purpose: A read-only film from the bundled catalog (movies_200.csv) or the
//  TMDB API. Saved copies on the shelf are OwnedTitle; a Movie is what the
//  add form can autofill from.
//  Used in: MovieCatalogService, ShelfSeeder, the "Type it in" form.
//

import Foundation

nonisolated struct Movie: Identifiable, Hashable, Sendable {
    /// The Movie Database (TMDB) ID from the dataset.
    let id: Int
    let imdbID: String?
    let title: String
    let genres: [String]
    let overview: String
    let year: Int?
    /// Runtime in minutes.
    let runtime: Int?
    let director: String
    /// Top-billed cast, in billing order.
    let cast: [String]
    let filmRating: FilmRating?
    /// True for TMDB search results, which don't include director, cast,
    /// runtime, or film rating until their details are fetched.
    var isSummary = false

    var moods: [Mood] { Mood.moods(forGenres: genres) }
    var posterLetter: String { TitleDisplay.posterLetter(for: title) }
    var imdbURL: URL? { TitleDisplay.imdbURL(imdbID: imdbID, title: title) }
    var trailerURL: URL? { TitleDisplay.trailerURL(title: title, year: year) }
}

// MARK: - Shared display helpers

/// Small formatting helpers shared by Movie and OwnedTitle.
nonisolated enum TitleDisplay {
    /// Leading words skipped when choosing the placeholder letter,
    /// so "The Matrix" shows "M" rather than "T".
    private static let articles = ["the ", "a ", "an "]

    /// The title without a leading "The", "A", or "An", for A–Z sorting,
    /// so "The Matrix" sorts under M.
    static func sortKey(for title: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        if let article = articles.first(where: { trimmed.lowercased().hasPrefix($0) }),
            trimmed.count > article.count
        {
            return String(trimmed.dropFirst(article.count))
        }
        return trimmed
    }

    /// The single letter shown on a title's placeholder poster.
    static func posterLetter(for title: String) -> String {
        guard let first = sortKey(for: title).first(where: { $0.isLetter || $0.isNumber }) else { return "?" }
        return String(first).uppercased()
    }

    /// Runtime as "1h 39m", "45m", or "2h".
    static func runtimeText(minutes: Int) -> String {
        let hours = minutes / 60
        let remainder = minutes % 60
        switch (hours, remainder) {
        case (0, _): return "\(remainder)m"
        case (_, 0): return "\(hours)h"
        default: return "\(hours)h \(remainder)m"
        }
    }

    /// A direct IMDb page when the ID is known, otherwise an IMDb title search.
    static func imdbURL(imdbID: String?, title: String) -> URL? {
        if let imdbID, !imdbID.isEmpty {
            return URL(string: "https://www.imdb.com/title/\(imdbID)/")
        }
        var components = URLComponents(string: "https://www.imdb.com/find/")
        components?.queryItems = [URLQueryItem(name: "q", value: title)]
        return components?.url
    }

    /// A YouTube search for the official trailer, e.g. "Up 2009 official trailer".
    /// Works for any title, including hand-entered ones, and opens in the
    /// YouTube app when it's installed (YouTube links are universal links).
    static func trailerURL(title: String, year: Int?) -> URL? {
        let query = [title, year.map(String.init), "official trailer"].compactMap { $0 }.joined(separator: " ")
        var components = URLComponents(string: "https://www.youtube.com/results")
        components?.queryItems = [URLQueryItem(name: "search_query", value: query)]
        return components?.url
    }
}

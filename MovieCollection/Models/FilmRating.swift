//
//  FilmRating.swift
//  MovieCollection
//
//  Purpose: The content rating on a film or show (G, PG, PG-13, R, TV-PG...),
//  used to filter for kid-friendly picks.
//  Used in: Movie, OwnedTitle, Tonight and search filters.
//

import Foundation

nonisolated enum FilmRating: String, Codable, CaseIterable, Identifiable, Sendable {
    case g = "G"
    case pg = "PG"
    case pg13 = "PG-13"
    case r = "R"
    case nc17 = "NC-17"
    case tvY = "TV-Y"
    case tvG = "TV-G"
    case tvPG = "TV-PG"
    case tv14 = "TV-14"
    case tvMA = "TV-MA"
    case notRated = "NR"

    var id: String { rawValue }

    /// Text shown on chips and the detail screen.
    var label: String {
        self == .notRated ? "Not rated" : rawValue
    }

    /// Ratings generally considered fine for watching with kids.
    var isKidFriendly: Bool {
        switch self {
        case .g, .pg, .tvY, .tvG, .tvPG: true
        default: false
        }
    }

    /// Ratings offered when the title is a movie.
    static let movieRatings: [FilmRating] = [.g, .pg, .pg13, .r, .nc17, .notRated]

    /// Ratings offered when the title is a TV show.
    static let tvRatings: [FilmRating] = [.tvY, .tvG, .tvPG, .tv14, .tvMA, .notRated]
}

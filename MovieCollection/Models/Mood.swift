//
//  Mood.swift
//  MovieCollection
//
//  Purpose: The "what are you in the mood for" tags used by Tonight.
//  For now moods are derived from a title's genres.
//  Used in: Movie, OwnedTitle, TonightViewModel.
//

import Foundation

nonisolated enum Mood: String, Codable, CaseIterable, Identifiable, Sendable {
    case feelGood = "Feel-good"
    case laughOutLoud = "Laugh out loud"
    case edgeOfSeat = "Edge of seat"
    case cozy = "Cozy"

    var id: String { rawValue }

    /// Genre names (as they appear in the dataset) mapped to the moods they suggest.
    /// A genre can point to more than one mood, and unlisted genres add none.
    private static let genreMap: [String: [Mood]] = [
        "Comedy": [.laughOutLoud],
        "Animation": [.laughOutLoud, .feelGood],
        "Family": [.feelGood],
        "Music": [.feelGood],
        "Fantasy": [.feelGood],
        "Romance": [.cozy],
        "Drama": [.cozy],
        "Action": [.edgeOfSeat],
        "Adventure": [.edgeOfSeat],
        "Thriller": [.edgeOfSeat],
        "Horror": [.edgeOfSeat],
        "Crime": [.edgeOfSeat],
        "Mystery": [.edgeOfSeat],
        "War": [.edgeOfSeat],
        "Science Fiction": [.edgeOfSeat],
    ]

    /// The moods for a set of genres, in the order Tonight lists them.
    static func moods(forGenres genres: [String]) -> [Mood] {
        let matched = Set(genres.flatMap { genreMap[$0] ?? [] })
        return allCases.filter { matched.contains($0) }
    }
}

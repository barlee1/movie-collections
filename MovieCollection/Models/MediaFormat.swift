//
//  MediaFormat.swift
//  MovieCollection
//
//  Purpose: How the user has a title (DVD, a digital copy they own, or through a
//  streaming subscription), the service it lives on, and whether it's a
//  movie or TV show.
//  Used in: OwnedTitle, shelf badges, detail location tags, filters, forms.
//

import Foundation

// MARK: - Format

nonisolated enum MediaFormat: String, Codable, CaseIterable, Identifiable, Sendable {
    case dvd = "DVD"
    case digital = "Digital"
    case streaming = "Streaming"

    var id: String { rawValue }

    /// DVD and Digital are owned; Streaming is only available while subscribed.
    var isOwned: Bool { self != .streaming }

    /// Digital and Streaming titles live on a service; DVDs don't.
    var needsService: Bool { self != .dvd }

    /// The location tag on the detail screen, e.g. "Owned · DVD" or "Streaming".
    var locationLabel: String {
        isOwned ? "Owned · \(rawValue)" : rawValue
    }

    /// The services that make sense to pick for this format.
    var allowedServices: [StreamingService] {
        switch self {
        case .dvd: []
        case .digital: StreamingService.digitalStores
        case .streaming: StreamingService.subscriptions
        }
    }

    /// The explanatory note under the location tag on the detail screen.
    func note(service: StreamingService?) -> String {
        let serviceName = service?.rawValue ?? "a service"
        return switch self {
        case .dvd: "Physical copy on your shelf"
        case .digital: "Digital copy you own on \(serviceName)"
        case .streaming: "Included with \(serviceName) — could leave the service"
        }
    }
}

// MARK: - Service

nonisolated enum StreamingService: String, Codable, CaseIterable, Identifiable, Sendable {
    case plex = "Plex"
    case amazonPrime = "Amazon Prime"
    case netflix = "Netflix"
    case hulu = "Hulu"
    case max = "Max"
    case disneyPlus = "Disney+"
    case appleTV = "Apple TV"
    case paramountPlus = "Paramount+"
    case peacock = "Peacock"
    case moviesAnywhere = "Movies Anywhere"
    case fandangoAtHome = "Fandango at Home"
    case youTube = "YouTube"

    var id: String { rawValue }

    /// Compact name for tight spots like the shelf card meta line.
    var shortName: String {
        self == .amazonPrime ? "Prime" : rawValue
    }

    /// Places where the user can own a digital copy.
    static let digitalStores: [StreamingService] = [
        .plex, .amazonPrime, .appleTV, .moviesAnywhere, .fandangoAtHome, .youTube,
    ]

    /// Subscription services a title can be streamed on.
    static let subscriptions: [StreamingService] = [
        .netflix, .amazonPrime, .hulu, .max, .disneyPlus, .appleTV, .paramountPlus, .peacock,
    ]
}

// MARK: - Kind

nonisolated enum TitleKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case movie = "Movie"
    case tvShow = "TV Show"

    var id: String { rawValue }

    /// TV shows credit creators rather than a director.
    var directorLabel: String {
        self == .tvShow ? "Creators" : "Director"
    }

    /// The rating options that apply to this kind of title.
    var ratingOptions: [FilmRating] {
        self == .tvShow ? FilmRating.tvRatings : FilmRating.movieRatings
    }
}

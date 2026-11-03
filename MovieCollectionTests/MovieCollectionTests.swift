//
//  MovieCollectionTests.swift
//  MovieCollectionTests
//
//  Created by Kylee Brown on 10/6/26.
//
//  Purpose: Shared helpers for the unit tests: a fresh in-memory shelf per
//  test, so tests never touch the real saved data or each other, and a fake
//  TMDB so tests never use the network.
//

import Foundation
import SwiftData

@testable import MovieCollection

enum TestSupport {

    /// A loaded AppViewModel backed by its own in-memory store, already
    /// set up as the sample user (subscriptions: Amazon Prime and Netflix).
    /// - Parameters:
    ///   - seeded: When true, the 30 sample titles are added. When false, the shelf starts empty.
    ///   - remoteCatalog: A stand-in for TMDB. Nil means offline, bundled catalog only.
    @MainActor
    static func makeAppModel(seeded: Bool = true, remoteCatalog: (any RemoteMovieCatalog)? = nil) async throws -> AppViewModel {
        let appModel = AppViewModel(
            store: CollectionStore(container: try CollectionStore.makeContainer(inMemory: true)),
            remoteCatalog: remoteCatalog,
            settings: try freshDefaults()
        )
        appModel.setProfile(.sample)
        appModel.loadsSampleShelfOnStart = seeded
        await appModel.start()
        guard appModel.loadState == .ready else {
            throw TestError.notReady("\(appModel.loadState)")
        }
        return appModel
    }

    /// An empty settings suite of its own.
    static func freshDefaults() throws -> UserDefaults {
        guard let defaults = UserDefaults(suiteName: "MovieCollectionTests-\(UUID().uuidString)") else {
            throw TestError.notReady("Couldn't create a test defaults suite")
        }
        return defaults
    }

    /// A catalog movie for tests that don't need the real catalog.
    static func movie(
        id: Int = 1,
        title: String = "Test Movie",
        genres: [String] = ["Comedy"],
        year: Int? = 2001,
        runtime: Int? = 95,
        director: String = "Jane Director",
        cast: [String] = ["Actor One", "Actor Two"],
        filmRating: FilmRating? = .pg,
        isSummary: Bool = false
    ) -> Movie {
        Movie(
            id: id, imdbID: "tt\(id)", title: title, genres: genres, overview: "",
            year: year, runtime: runtime, director: director, cast: cast, filmRating: filmRating,
            isSummary: isSummary
        )
    }

    /// A TMDB-style search result: title and year, but no director, cast, or rating.
    static func summary(id: Int, title: String, year: Int? = 2001) -> Movie {
        Movie(
            id: id, imdbID: nil, title: title, genres: ["Drama"], overview: "",
            year: year, runtime: nil, director: "", cast: [], filmRating: nil, isSummary: true
        )
    }

    enum TestError: Error {
        case notReady(String)
    }
}

/// A stand-in for TMDB that returns canned movies and counts its calls.
/// Only used from the main actor in tests, so the unchecked Sendable is safe.
nonisolated final class FakeRemoteCatalog: RemoteMovieCatalog, @unchecked Sendable {
    /// Summaries returned by every search.
    var searchResults: [Movie]
    /// Full details by movie ID.
    var details: [Int: Movie]
    /// When true, every call throws, like being offline.
    var isOffline = false
    private(set) var searchCount = 0
    private(set) var detailsCount = 0

    struct Offline: Error {}

    init(searchResults: [Movie] = [], details: [Int: Movie] = [:]) {
        self.searchResults = searchResults
        self.details = details
    }

    func searchMovies(_ query: String, year: Int?) async throws -> [Movie] {
        searchCount += 1
        if isOffline { throw Offline() }
        return searchResults
    }

    func movieDetails(id: Int) async throws -> Movie {
        detailsCount += 1
        if isOffline { throw Offline() }
        guard let movie = details[id] else { throw Offline() }
        return movie
    }
}

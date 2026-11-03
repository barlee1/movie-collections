//
//  TonightTests.swift
//  MovieCollectionTests
//
//  Purpose: Tonight's mood filters, kid-friendly rating filter, and the
//  random pick.
//

import Foundation
import SwiftData
import Testing

@testable import MovieCollection

@Suite("Tonight")
@MainActor
struct TonightViewModelTests {

    @Test("By default only titles Ella hasn't reviewed are offered")
    func defaultsToNotReviewed() async throws {
        let tonight = TonightViewModel(appModel: try await TestSupport.makeAppModel())
        #expect(tonight.matches.count == 28)
        #expect(tonight.matches.allSatisfy { !$0.isReviewed })
        #expect(tonight.matchLabel == "28 on your shelf fit")

        tonight.seen = .rewatch
        #expect(tonight.matches.count == 2)
        tonight.seen = .anything
        #expect(tonight.matches.count == 30)
    }

    @Test("Picking G and PG leaves only kid-friendly titles")
    func kidFriendlyRatings() async throws {
        let appModel = try await TestSupport.makeAppModel()
        let tonight = TonightViewModel(appModel: appModel)
        tonight.ratings = [.g, .pg]

        let expected = appModel.titles.filter { !$0.isReviewed && [.g, .pg].contains($0.filmRating) }
        #expect(tonight.matches.count == expected.count)
        #expect(tonight.matches.allSatisfy { $0.filmRating?.isKidFriendly == true })
        #expect(!tonight.matches.isEmpty)
    }

    @Test("Mood, genre, runtime, and format all narrow the matches")
    func combinedFilters() async throws {
        let tonight = TonightViewModel(appModel: try await TestSupport.makeAppModel())
        tonight.seen = .anything

        tonight.moods = [.laughOutLoud]
        #expect(tonight.matches.allSatisfy { $0.moods.contains(.laughOutLoud) })

        tonight.genres = ["Animation"]
        #expect(tonight.matches.allSatisfy { $0.genres.contains("Animation") })

        tonight.runtime = .upTo100
        #expect(tonight.matches.allSatisfy { ($0.runtime ?? 0) <= 100 })

        tonight.format = .dvd
        #expect(tonight.matches.allSatisfy { $0.format == .dvd })
        #expect(!tonight.matches.isEmpty, "Toy Story, Finding Nemo, or Up should still fit")
    }

    @Test("Titles without a known runtime aren't ruled out by length")
    func unknownRuntime() async throws {
        let appModel = try await TestSupport.makeAppModel(seeded: false)
        appModel.add(OwnedTitle(title: "No Runtime", runtime: nil, format: .dvd))
        appModel.add(OwnedTitle(title: "Long One", runtime: 200, format: .dvd))
        let tonight = TonightViewModel(appModel: appModel)
        tonight.runtime = .upTo120
        #expect(tonight.matches.map(\.title) == ["No Runtime"])
    }

    @Test("Genre options are the shelf's genres, most common first")
    func genreOptions() async throws {
        let tonight = TonightViewModel(appModel: try await TestSupport.makeAppModel())
        let options = tonight.genreOptions
        #expect(Set(options).count == options.count)
        #expect(options.first == "Adventure")
    }

    @Test("Pick another never repeats the current title when there's a choice")
    func pickAvoidsRepeat() async throws {
        let tonight = TonightViewModel(appModel: try await TestSupport.makeAppModel())
        let first = try #require(tonight.pick())
        for _ in 0..<25 {
            #expect(tonight.pick(excluding: first) != first)
        }
    }

    @Test("With one match it's always picked; with none, nothing is")
    func pickEdgeCases() async throws {
        let appModel = try await TestSupport.makeAppModel(seeded: false)
        let tonight = TonightViewModel(appModel: appModel)
        #expect(tonight.pick() == nil)
        #expect(tonight.matchLabel == "Nothing fits — loosen a filter")

        let only = OwnedTitle(title: "Only One", format: .dvd)
        appModel.add(only)
        #expect(tonight.pick(excluding: only.persistentModelID) == only.persistentModelID)
        #expect(tonight.matchLabel == "1 on your shelf fits")
    }
}

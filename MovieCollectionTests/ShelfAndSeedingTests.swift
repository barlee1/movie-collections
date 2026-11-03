//
//  ShelfAndSeedingTests.swift
//  MovieCollectionTests
//
//  Purpose: The optional sample shelf, saving through AppViewModel, and the
//  Shelf tab's filters and labels.
//

import Foundation
import SwiftData
import Testing

@testable import MovieCollection

@Suite("Starting shelf")
@MainActor
struct SeedingTests {

    @Test("Seeds 30 movies with the design's two reviews")
    func seedsShelf() async throws {
        let appModel = try await TestSupport.makeAppModel()
        #expect(appModel.titles.count == 30)
        #expect(appModel.movieCount == 30)
        #expect(appModel.tvShowCount == 0)
        let reviewed = appModel.reviewedTitles.map(\.title)
        #expect(reviewed == ["Star Wars: Episode I - The Phantom Menace", "The Lake House"])
        #expect(appModel.titles.allSatisfy { $0.format.needsService == ($0.service != nil) })
    }

    @Test("A new shelf starts empty; the sample is never added on its own")
    func startsEmpty() async throws {
        let appModel = try await TestSupport.makeAppModel(seeded: false)
        #expect(appModel.titles.isEmpty)
        #expect(!appModel.isSampleShelfLoaded)
    }

    @Test("Loading the sample shelf on request adds 30 titles, once")
    func loadsOnRequest() async throws {
        let appModel = try await TestSupport.makeAppModel(seeded: false)
        #expect(appModel.loadSampleShelf() == 30)
        #expect(appModel.isSampleShelfLoaded)
        #expect(appModel.loadSampleShelf() == 0, "Loading again doesn't add duplicates")
        #expect(appModel.titles.count == 30)
    }

    @Test("Keeps the user's own titles and adds back only missing samples")
    func addsOnlyMissing() async throws {
        let appModel = try await TestSupport.makeAppModel()
        let toyStory = try #require(appModel.titles.first { $0.title == "Toy Story" })
        appModel.remove(toyStory)
        appModel.add(OwnedTitle(title: "Hand Entered", format: .dvd))
        #expect(!appModel.isSampleShelfLoaded)

        #expect(appModel.loadSampleShelf() == 1)
        #expect(appModel.titles.count == 31)
        #expect(appModel.titles.contains { $0.title == "Hand Entered" })
    }
}

@Suite("Saving changes")
@MainActor
struct AppViewModelTests {

    @Test("Adding, reviewing, and removing a title updates every derived list")
    func addReviewRemove() async throws {
        let appModel = try await TestSupport.makeAppModel(seeded: false)
        let title = OwnedTitle(title: "Corner Gas", kind: .tvShow, format: .dvd)
        #expect(appModel.add(title))
        #expect(appModel.tvShowCount == 1)

        #expect(appModel.saveReview(for: title, rating: 3.7, text: "Cozy"))
        #expect(title.review?.rating == 3.5)
        #expect(appModel.reviewedTitles.count == 1)

        // Saving again updates the same review instead of adding another.
        #expect(appModel.saveReview(for: title, rating: 5, text: "Even better"))
        #expect(try appModel.store.allReviews().count == 1)
        #expect(title.review?.text == "Even better")

        #expect(appModel.remove(title))
        #expect(appModel.titles.isEmpty)
        #expect(try appModel.store.allReviews().isEmpty, "Removing a title removes its review")
        #expect(appModel.title(with: title.persistentModelID) == nil)
    }

    @Test("Catalog search is case-insensitive and limited")
    func catalogMatches() async throws {
        let appModel = try await TestSupport.makeAppModel(seeded: false)
        let matches = appModel.catalogMatches(for: "HARRY")
        #expect(matches.count == 5)
        #expect(matches.allSatisfy { $0.title.contains("Harry") })
        #expect(appModel.catalogMatches(for: "   ").isEmpty)
    }
}

@Suite("Shelf filters")
@MainActor
struct ShelfViewModelTests {

    @Test("The reviewed chips split the shelf")
    func seenFilter() async throws {
        let shelf = ShelfViewModel(appModel: try await TestSupport.makeAppModel())
        #expect(shelf.visibleTitles.count == 30)
        shelf.seen = .reviewed
        #expect(shelf.visibleTitles.count == 2)
        shelf.seen = .notReviewed
        #expect(shelf.visibleTitles.count == 28)
        #expect(shelf.subtitle == "30 titles · 28 not reviewed yet")
    }

    @Test("Each search filter narrows the results")
    func searchFilters() async throws {
        let appModel = try await TestSupport.makeAppModel()
        let shelf = ShelfViewModel(appModel: appModel)

        shelf.filters.query = "harry"
        #expect(shelf.visibleTitles.count == 2)
        shelf.clearFilters()

        shelf.filters.formats = [.dvd]
        #expect(shelf.visibleTitles.allSatisfy { $0.format == .dvd })
        #expect(shelf.visibleTitles.count == appModel.titles.filter { $0.format == .dvd }.count)
        shelf.clearFilters()

        shelf.filters.services = [.netflix]
        #expect(!shelf.visibleTitles.isEmpty)
        #expect(shelf.visibleTitles.allSatisfy { $0.service == .netflix })
        shelf.clearFilters()

        shelf.filters.ratings = [.r]
        #expect(Set(shelf.visibleTitles.map(\.title)) == ["The Shawshank Redemption", "The Matrix", "The Grand Budapest Hotel"])
        shelf.clearFilters()

        shelf.filters.actor = "hanks"
        #expect(Set(shelf.visibleTitles.map(\.title)).isSuperset(of: ["Apollo 13", "Forrest Gump", "Catch Me If You Can"]))
        shelf.clearFilters()

        // Text filters match anywhere in the name, like the design, so this also
        // finds Zootopia (directed by "Byron Howard").
        shelf.filters.director = "Ron Howard"
        #expect(Set(shelf.visibleTitles.map(\.title)) == ["Apollo 13", "Zootopia"])
        #expect(shelf.visibleTitles.allSatisfy { $0.director.localizedStandardContains("ron howard") })
        shelf.clearFilters()

        shelf.filters.year = "199"
        #expect(shelf.visibleTitles.allSatisfy { ($0.year ?? 0) >= 1990 && ($0.year ?? 0) < 2000 })
        #expect(!shelf.visibleTitles.isEmpty)
    }

    @Test("Filter count and clearing, which keeps the reviewed chip")
    func filterCount() async throws {
        let shelf = ShelfViewModel(appModel: try await TestSupport.makeAppModel())
        shelf.seen = .reviewed
        shelf.filters.query = "lake"
        shelf.filters.formats = [.dvd, .digital]
        shelf.filters.year = " "
        #expect(shelf.filters.activeCount == 3, "Blank text fields don't count")
        #expect(shelf.searchLabel == "lake")
        #expect(shelf.showResultsLabel == "Show 1 title")

        shelf.clearFilters()
        #expect(shelf.filters.activeCount == 0)
        #expect(shelf.seen == .reviewed)
        #expect(shelf.searchLabel == "Search titles")
    }

    @Test("Card details show stars once reviewed, otherwise the film rating")
    func cardMeta() async throws {
        let appModel = try await TestSupport.makeAppModel()
        let lakeHouse = try #require(appModel.titles.first { $0.title == "The Lake House" })
        #expect(ShelfViewModel.meta(for: lakeHouse) == "2006 · 4/5")

        let megamind = try #require(appModel.titles.first { $0.title == "Megamind" })
        #expect(ShelfViewModel.meta(for: megamind) == "2010 · PG · Prime")

        appModel.saveReview(for: megamind, rating: 3.5, text: "")
        #expect(ShelfViewModel.meta(for: megamind) == "2010 · 3.5/5 · Prime")
    }

    @Test("Service options include Ella's subscriptions even if unused")
    func serviceOptions() async throws {
        let shelf = ShelfViewModel(appModel: try await TestSupport.makeAppModel(seeded: false))
        #expect(shelf.serviceOptions == [.amazonPrime, .netflix])
        #expect(shelf.ratingOptions.isEmpty)
    }
}

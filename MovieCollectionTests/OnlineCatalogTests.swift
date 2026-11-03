//
//  OnlineCatalogTests.swift
//  MovieCollectionTests
//
//  Purpose: The TMDB catalog: reading TMDB's JSON, building requests, merging
//  online results with the bundled catalog, falling back when offline, and
//  filling in the add form and spreadsheet import. Uses a fake TMDB, so no
//  network or key is needed. Also checks the versioned SwiftData store.
//

import Foundation
import SwiftData
import Testing

@testable import MovieCollection

@Suite("TMDB parsing and requests")
struct TMDBClientTests {

    @Test("Search results become summaries with years and genre names")
    func parsesSearch() throws {
        let json = """
            {"page":1,"results":[
              {"id":550,"title":"Fight Club","overview":"An insomniac...","release_date":"1999-10-15","genre_ids":[18,53]},
              {"id":9999,"title":"No Date","release_date":"","genre_ids":[123456]}
            ]}
            """
        let movies = try TMDBClient.parseSearch(Data(json.utf8))
        #expect(movies.count == 2)
        let fightClub = try #require(movies.first)
        #expect(fightClub.id == 550)
        #expect(fightClub.year == 1999)
        #expect(fightClub.genres == ["Drama", "Thriller"])
        #expect(fightClub.isSummary)
        #expect(fightClub.director.isEmpty)
        #expect(movies[1].year == nil)
        #expect(movies[1].genres.isEmpty, "Unknown genre IDs are skipped")
    }

    @Test("Details include director, top cast in billing order, and the US rating")
    func parsesDetails() throws {
        let json = """
            {"id":550,"imdb_id":"tt0137523","title":"Fight Club","overview":"An insomniac...",
             "release_date":"1999-10-15","runtime":139,"genres":[{"id":18,"name":"Drama"}],
             "credits":{
               "cast":[{"name":"Helena Bonham Carter","order":2},{"name":"Brad Pitt","order":1},
                       {"name":"Edward Norton","order":0},{"name":"Meat Loaf","order":3},
                       {"name":"Jared Leto","order":4},{"name":"Zach Grenier","order":5}],
               "crew":[{"name":"David Fincher","job":"Director"},{"name":"Jim Uhls","job":"Screenplay"}]},
             "release_dates":{"results":[
               {"iso_3166_1":"GB","release_dates":[{"certification":"18","type":3}]},
               {"iso_3166_1":"US","release_dates":[{"certification":"","type":1},{"certification":"R","type":3}]}]}}
            """
        let movie = try TMDBClient.parseDetails(Data(json.utf8))
        #expect(!movie.isSummary)
        #expect(movie.imdbID == "tt0137523")
        #expect(movie.year == 1999)
        #expect(movie.runtime == 139)
        #expect(movie.director == "David Fincher")
        #expect(movie.cast == ["Edward Norton", "Brad Pitt", "Helena Bonham Carter", "Meat Loaf", "Jared Leto"])
        #expect(movie.filmRating == .r)
        #expect(movie.genres == ["Drama"])
    }

    @Test("Missing credits and ratings leave those fields empty")
    func parsesSparseDetails() throws {
        let json = #"{"id":1,"title":"Tiny","runtime":0,"imdb_id":""}"#
        let movie = try TMDBClient.parseDetails(Data(json.utf8))
        #expect(movie.director.isEmpty)
        #expect(movie.cast.isEmpty)
        #expect(movie.filmRating == nil)
        #expect(movie.runtime == nil, "A zero runtime means unknown")
        #expect(movie.imdbID == nil)
    }

    @Test("A read access token goes in the header")
    func bearerRequest() throws {
        let client = TMDBClient(credential: .readAccessToken("abc.def"))
        let request = client.request("search/movie", [URLQueryItem(name: "query", value: "Up")])
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer abc.def")
        let url = try #require(request.url?.absoluteString)
        #expect(url.hasPrefix("https://api.themoviedb.org/3/search/movie?"))
        #expect(url.contains("query=Up"))
        #expect(!url.contains("api_key"))
    }

    @Test("An API key goes in the query instead")
    func apiKeyRequest() throws {
        let client = TMDBClient(credential: .apiKey("12345"))
        let request = client.request("movie/550", [])
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(request.url?.absoluteString.contains("api_key=12345") == true)
    }
}

@Suite("Online catalog in the app")
@MainActor
struct OnlineCatalogTests {

    @Test("Without TMDB, search uses only the bundled catalog")
    func offlineByDefault() async throws {
        let appModel = try await TestSupport.makeAppModel(seeded: false)
        #expect(!appModel.hasOnlineCatalog)
        let results = await appModel.searchMovies("Shrek")
        #expect(results.first?.title == "Shrek")
        #expect(results.allSatisfy { !$0.isSummary })
    }

    @Test("Bundled matches come first, and TMDB duplicates are dropped")
    func mergesResults() async throws {
        let shrekID = 808  // Shrek's TMDB ID in the bundled catalog
        let remote = FakeRemoteCatalog(searchResults: [
            TestSupport.summary(id: shrekID, title: "Shrek"),
            TestSupport.summary(id: 10192, title: "Shrek Forever After", year: 2010),
        ])
        let appModel = try await TestSupport.makeAppModel(seeded: false, remoteCatalog: remote)
        let results = await appModel.searchMovies("Shrek")
        #expect(results.filter { $0.id == shrekID }.count == 1)
        #expect(results.first { $0.id == shrekID }?.isSummary == false, "The bundled copy wins")
        #expect(results.last?.title == "Shrek Forever After")
        #expect(appModel.movie(withID: 10192)?.title == "Shrek Forever After", "Results can be opened by ID")
    }

    @Test("Offline TMDB falls back to bundled results")
    func offlineFallback() async throws {
        let remote = FakeRemoteCatalog()
        remote.isOffline = true
        let appModel = try await TestSupport.makeAppModel(seeded: false, remoteCatalog: remote)
        let results = await appModel.searchMovies("Shrek")
        #expect(results.first?.title == "Shrek")

        let summary = TestSupport.summary(id: 42, title: "Unreachable")
        #expect(await appModel.fullDetails(for: summary) == summary, "Keeps the summary when details can't load")
    }

    @Test("Details are fetched once, then reused")
    func cachesDetails() async throws {
        let full = TestSupport.movie(id: 42, title: "Remote Movie", director: "Ava Director")
        let remote = FakeRemoteCatalog(details: [42: full])
        let appModel = try await TestSupport.makeAppModel(seeded: false, remoteCatalog: remote)
        let summary = TestSupport.summary(id: 42, title: "Remote Movie")

        #expect(await appModel.fullDetails(for: summary).director == "Ava Director")
        #expect(await appModel.fullDetails(for: summary).director == "Ava Director")
        #expect(remote.detailsCount == 1)
        #expect(appModel.movie(withID: 42)?.director == "Ava Director")
    }

    @Test("Picking a TMDB suggestion fills in the details it was missing")
    func addFormFetchesDetails() async throws {
        let summary = TestSupport.summary(id: 4242, title: "Arrival Zzz", year: 2016)
        let full = TestSupport.movie(
            id: 4242, title: "Arrival Zzz", year: 2016, runtime: 116,
            director: "Denis Villeneuve", cast: ["Amy Adams"], filmRating: .pg13
        )
        let remote = FakeRemoteCatalog(searchResults: [summary], details: [4242: full])
        let appModel = try await TestSupport.makeAppModel(seeded: false, remoteCatalog: remote)
        let form = AddTitleViewModel(appModel: appModel)

        form.title = "Arrival Zzz"
        await form.searchOnline()
        let suggestion = try #require(form.suggestions.first { $0.id == 4242 })
        await form.choose(suggestion)

        #expect(form.director == "Denis Villeneuve")
        #expect(form.runtimeText == "116")
        #expect(form.filmRating == .pg13)
        #expect(!form.isLoadingDetails)

        let id = try #require(form.save())
        #expect(appModel.title(with: id)?.catalogID == 4242)
    }

    @Test("Spreadsheet rows missing from the bundled catalog are looked up online")
    func importLooksUpOnline() async throws {
        let full = TestSupport.movie(id: 777, title: "Obscure Gem", year: 1987, director: "Rita Indie", filmRating: .r)
        let remote = FakeRemoteCatalog(
            searchResults: [TestSupport.summary(id: 777, title: "Obscure Gem", year: 1987)],
            details: [777: full]
        )
        let appModel = try await TestSupport.makeAppModel(seeded: false, remoteCatalog: remote)
        let importer = SpreadsheetImportViewModel(appModel: appModel)
        importer.load(csv: "Title,Year\nObscure Gem,1987\nShrek,2001\n")
        await importer.matchRowsOnline()

        let gem = try #require(importer.rows.first { $0.title == "Obscure Gem" })
        #expect(gem.catalogMatch?.director == "Rita Indie")
        #expect(gem.filmRating == .r)
        #expect(remote.searchCount >= 1)

        importer.importSelected()
        #expect(appModel.titles.first { $0.title == "Obscure Gem" }?.director == "Rita Indie")
    }
}

@Suite("Saved data versions")
@MainActor
struct SchemaTests {

    @Test("The store uses version 1 of the schema with its migration plan")
    func versionedStore() throws {
        #expect(SchemaV1.versionIdentifier == Schema.Version(1, 0, 0))
        #expect(RewindClubMigrationPlan.schemas.count == 1)
        let container = try CollectionStore.makeContainer(inMemory: true)
        let entityNames = Set(container.schema.entities.map(\.name))
        #expect(entityNames == ["OwnedTitle", "Review"])
    }

    @Test("Titles and reviews save and load through the versioned store")
    func roundTrip() throws {
        let store = CollectionStore(container: try CollectionStore.makeContainer(inMemory: true))
        let title = OwnedTitle(title: "Versioned", format: .dvd)
        try store.add(title)
        try store.saveReview(for: title, rating: 4, text: "Still here")
        #expect(try store.allTitles().first?.review?.text == "Still here")
    }
}

//
//  DataLoadingTests.swift
//  MovieCollectionTests
//
//  Purpose: The CSV reader and the bundled 200-movie catalog.
//

import Foundation
import Testing

@testable import MovieCollection

@Suite("CSV parser")
struct CSVParserTests {

    @Test("Splits plain rows and fields")
    func plainRows() {
        let rows = CSVParser.parse("a,b,c\n1,2,3\n")
        #expect(rows == [["a", "b", "c"], ["1", "2", "3"]])
    }

    @Test("Keeps commas, doubled quotes, and line breaks inside quoted fields")
    func quotedFields() {
        let rows = CSVParser.parse("\"x, y\",\"he said \"\"hi\"\"\",\"line1\nline2\"\n")
        #expect(rows == [["x, y", "he said \"hi\"", "line1\nline2"]])
    }

    @Test("Handles Windows line endings, blank lines, and a missing final newline")
    func lineEndings() {
        let rows = CSVParser.parse("a,b\r\n\r\n1,\r\n2,3")
        #expect(rows == [["a", "b"], ["1", ""], ["2", "3"]])
    }

    @Test("Maps rows to the header, ignoring missing trailing columns")
    func records() {
        let records = CSVParser.parseRecords("id,title,genres\n1,Up\n2,Cars,Animation")
        #expect(records.count == 2)
        #expect(records[0]["title"] == "Up")
        #expect(records[0]["genres"] == nil)
        #expect(records[1]["genres"] == "Animation")
    }

    @Test("Empty text gives no rows")
    func empty() {
        #expect(CSVParser.parse("").isEmpty)
        #expect(CSVParser.parseRecords("").isEmpty)
    }
}

@Suite("Movie catalog")
struct MovieCatalogTests {

    private let sampleCSV = """
        id,imdb_id,title,genres,overview,release_date,runtime,director,cast,film_rating
        2044,tt0410297,The Lake House,Romance|Drama,"A lonely doctor, a mailbox.",2006-06-16,99,Alejandro Agresti,Keanu Reeves|Sandra Bullock,PG
        ,tt0,No ID,Drama,,2000-01-01,90,,,PG
        3,,   ,Drama,,2000-01-01,90,,,PG
        4,,Mystery Film,,,,,,,XYZ
        """

    @Test("Parses every column, splitting genres and cast")
    func parsesColumns() throws {
        let movies = MovieCatalogService.parseMovies(csv: sampleCSV)
        let lakeHouse = try #require(movies.first { $0.id == 2044 })
        #expect(lakeHouse.title == "The Lake House")
        #expect(lakeHouse.imdbID == "tt0410297")
        #expect(lakeHouse.genres == ["Romance", "Drama"])
        #expect(lakeHouse.overview == "A lonely doctor, a mailbox.")
        #expect(lakeHouse.year == 2006)
        #expect(lakeHouse.runtime == 99)
        #expect(lakeHouse.director == "Alejandro Agresti")
        #expect(lakeHouse.cast == ["Keanu Reeves", "Sandra Bullock"])
        #expect(lakeHouse.filmRating == .pg)
    }

    @Test("Skips rows without an ID or title, and tolerates missing values")
    func skipsBadRows() throws {
        let movies = MovieCatalogService.parseMovies(csv: sampleCSV)
        #expect(movies.map(\.id) == [2044, 4])
        let sparse = try #require(movies.last)
        #expect(sparse.year == nil)
        #expect(sparse.runtime == nil)
        #expect(sparse.genres.isEmpty)
        #expect(sparse.imdbID == nil)
        #expect(sparse.filmRating == nil)  // "XYZ" isn't a known rating
    }

    @Test("The bundled catalog has 200 complete movies")
    func bundledCatalog() async throws {
        let movies = try await MovieCatalogService().loadMovies()
        #expect(movies.count == 200)
        #expect(Set(movies.map(\.id)).count == 200, "Movie IDs should be unique")
        #expect(movies.allSatisfy { $0.filmRating != nil })
        #expect(movies.allSatisfy { $0.year != nil })
        #expect(movies.allSatisfy { !$0.director.isEmpty })
        #expect(movies.allSatisfy { !$0.moods.isEmpty })
        // The design's sample movies that were swapped in.
        let titles = Set(movies.map(\.title))
        #expect(titles.isSuperset(of: ["Megamind", "The Lake House", "Apollo 13", "Batman Begins"]))
    }

    @Test("A missing catalog file throws a clear error")
    func missingFile() async {
        await #expect(throws: MovieCatalogService.CatalogError.self) {
            try await MovieCatalogService(fileURL: nil).loadMovies()
        }
    }
}

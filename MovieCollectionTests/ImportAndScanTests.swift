//
//  ImportAndScanTests.swift
//  MovieCollectionTests
//
//  Purpose: Title matching, the cover scanner (including a real on-device
//  Vision read of a rendered cover), the spreadsheet and Letterboxd
//  importers, and the watched progress count.
//

import Foundation
import SwiftData
import SwiftUI
import Testing

@testable import MovieCollection

@Suite("Title matching")
struct TitleMatchingTests {

    @Test(
        "Normalizing ignores case, accents, punctuation, '&', and a leading article",
        arguments: [
            ("The Lord of the Rings: The Return of the King", "lord of the rings the return of the king"),
            ("Léon: The Professional", "leon the professional"),
            ("Fast & Furious 6", "fast and furious 6"),
            ("WALL·E", "wall e"),
            ("  The  ", "the"),
        ])
    func normalize(input: String, expected: String) {
        #expect(TitleMatcher.normalize(input) == expected)
    }

    @Test("Finding a catalog movie prefers the matching year")
    func findMovie() {
        let catalog = [
            TestSupport.movie(id: 1, title: "Beauty and the Beast", year: 1991),
            TestSupport.movie(id: 2, title: "Beauty and the Beast", year: 2017),
        ]
        #expect(TitleMatcher.findMovie(title: "beauty & the beast", year: 2017, in: catalog)?.id == 2)
        #expect(TitleMatcher.findMovie(title: "Beauty and the Beast", year: nil, in: catalog)?.id == 1)
        #expect(TitleMatcher.findMovie(title: "Beauty and the Beast", year: 1950, in: catalog) == nil)
    }
}

@Suite("Cover scanner")
@MainActor
struct CoverScannerTests {

    private func catalog() async throws -> [Movie] {
        try await MovieCatalogService().loadMovies()
    }

    @Test("Finds the title among the other text on a case")
    func findsTitle() async throws {
        let lines = ["LEONARDO DICAPRIO", "INCEPTION", "YOUR MIND IS THE SCENE OF THE CRIME", "DVD", "PG-13"]
        #expect(CoverMatcher.rankMovies(for: lines, in: try await catalog()).first?.title == "Inception")
    }

    @Test("A sequel number wins over the original")
    func prefersSequel() async throws {
        let matches = CoverMatcher.rankMovies(for: ["DISNEY PIXAR", "TOY STORY 3"], in: try await catalog())
        #expect(matches.first?.title == "Toy Story 3")
    }

    @Test("Short titles only match when they stand alone")
    func shortTitles() async throws {
        let movies = try await catalog()
        #expect(CoverMatcher.rankMovies(for: ["Pick up the pieces"], in: movies).isEmpty)
        #expect(CoverMatcher.rankMovies(for: ["UP"], in: movies).first?.title == "Up")
    }

    @Test("Titles split across lines still match")
    func splitTitle() async throws {
        let lines = ["HARRY POTTER", "and the", "PRISONER OF AZKABAN"]
        #expect(
            CoverMatcher.rankMovies(for: lines, in: try await catalog()).first?.title
                == "Harry Potter and the Prisoner of Azkaban")
    }

    @Test("Vision reads a rendered cover on device and it matches the catalog")
    func readsRenderedCover() async throws {
        let cover = VStack(spacing: 20) {
            Text("CHRISTIAN BALE").font(.system(size: 16, weight: .semibold))
            Text("BATMAN BEGINS")
                .font(.system(size: 40, weight: .heavy))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .foregroundStyle(.white)
        .padding(30)
        .frame(width: 360, height: 240)
        .background(.black)

        let renderer = ImageRenderer(content: cover)
        renderer.scale = 3
        let data = try #require(renderer.uiImage?.pngData())

        let lines = try await CoverTextReader.lines(in: data)
        #expect(lines.contains { $0.localizedCaseInsensitiveContains("batman begins") }, "Read: \(lines)")

        let appModel = try await TestSupport.makeAppModel(seeded: false)
        let scanner = CoverScanViewModel(appModel: appModel)
        await scanner.read(imageData: data)
        #expect(scanner.matches.first?.title == "Batman Begins")
        #expect(scanner.hasScanned)
    }
}

@Suite("Spreadsheet import")
@MainActor
struct SpreadsheetImportTests {

    @Test("Reads formats and services as people type them")
    func parsing() {
        #expect(ImportParsing.service("Prime") == .amazonPrime)
        #expect(ImportParsing.service("Disney+") == .disneyPlus)
        #expect(ImportParsing.service("HBO Max") == .max)
        #expect(ImportParsing.service("Vudu") == .fandangoAtHome)
        #expect(ImportParsing.service("Blockbuster") == nil)
        #expect(ImportParsing.format("Blu-ray") == .dvd)
        #expect(ImportParsing.format("streaming") == .streaming)
        #expect(ImportParsing.date("2024-09-25") != nil)
        #expect(ImportParsing.date("9/25/2024") != nil)
    }

    @Test("Parses rows, matches the catalog, infers formats, and flags duplicates")
    func parsesRows() async throws {
        let appModel = try await TestSupport.makeAppModel()
        let csv = """
            title,year,service,rating,watched,type
            shrek,2001,,,,
            Coco,2017,Netflix,PG,yes,
            The Lion King,,Apple TV,,2025-01-02,
            Toy Story,1995,,,,
            ,1999,,,,
            Corner Gas,2004,,TV-PG,,tv show
            """
        let result = SpreadsheetImporter.parse(
            csv: csv, catalog: appModel.catalog,
            shelf: appModel.titles.map { ($0.title, $0.year) })
        #expect(result.titles.count == 5)
        #expect(result.skippedRows == 1)

        let shrek = try #require(result.titles.first { $0.title == "Shrek" })
        #expect(shrek.catalogMatch?.id == 808, "Matched despite lowercase")
        #expect(shrek.format == .dvd, "No service means a disc")
        #expect(shrek.filmRating == .pg, "Rating filled in from the catalog")

        let coco = try #require(result.titles.first { $0.title == "Coco" })
        #expect(coco.format == .streaming, "Netflix is subscription-only")
        #expect(coco.lastWatched != nil, "\"yes\" counts as watched")
        #expect(coco.catalogMatch == nil)

        let lionKing = try #require(result.titles.first { $0.title == "The Lion King" })
        #expect(lionKing.format == .digital, "Apple TV sells digital copies")
        #expect(lionKing.year == 1994, "Year filled in from the catalog")

        #expect(result.titles.first { $0.title == "Toy Story" }?.isAlreadyOnShelf == true)
        #expect(result.titles.first { $0.title == "Corner Gas" }?.kind == .tvShow)
    }

    @Test("The sample spreadsheet adds only the checked, new titles")
    func importsSample() async throws {
        let appModel = try await TestSupport.makeAppModel()
        let importer = SpreadsheetImportViewModel(appModel: appModel)
        importer.loadSample()
        #expect(importer.phase == .preview)
        #expect(importer.rows.count == 8)
        #expect(importer.selectedCount == 7, "Toy Story is already on the shelf")

        let coco = try #require(importer.rows.first { $0.title == "Coco" })
        importer.toggle(coco)  // Leave Coco out.
        importer.importSelected()

        #expect(importer.phase == .done(count: 6))
        #expect(appModel.titles.count == 36)
        #expect(!appModel.titles.contains { $0.title == "Coco" })
        #expect(appModel.tvShowCount == 1, "Corner Gas came in as a TV show")
        let shrek = try #require(appModel.titles.first { $0.title == "Shrek" })
        #expect(shrek.director == "Andrew Adamson, Vicky Jenson", "Catalog details filled in")
    }

    @Test("A file without a title column shows an error and stays on the picker")
    func badFile() async throws {
        let importer = SpreadsheetImportViewModel(appModel: try await TestSupport.makeAppModel())
        importer.load(csv: "name only,nothing\n,\n")
        #expect(importer.errorMessage != nil)
        #expect(importer.phase == .choosing)
    }
}

@Suite("Letterboxd import")
@MainActor
struct LetterboxdImportTests {

    @Test("Merges several export files, keeping the latest watch date and the review")
    func mergesFiles() {
        let ratings = """
            Date,Name,Year,Letterboxd URI,Rating
            2024-01-01,Inception,2010,https://boxd.it/a,4
            """
        let diary = """
            Date,Name,Year,Letterboxd URI,Rating,Rewatch,Tags,Watched Date
            2024-06-02,Inception,2010,https://boxd.it/a,4.5,Yes,,2024-06-01
            2023-03-03,Inception,2010,https://boxd.it/a,,,,2023-03-03
            """
        let entries = LetterboxdImporter.parse(csvFiles: [ratings, diary])
        let inception = try? #require(entries.first)
        #expect(entries.count == 1)
        #expect(inception?.rating == 4.5)
        #expect(Calendar.current.component(.month, from: inception?.watchedDate ?? .distantPast) == 6)
    }

    @Test("Updates matching shelf titles and lists the rest as not on the shelf")
    func appliesSample() async throws {
        let appModel = try await TestSupport.makeAppModel()
        let importer = LetterboxdImportViewModel(appModel: appModel)
        importer.loadSample()
        #expect(importer.matches.count == 6)
        #expect(Set(importer.unmatched.map(\.name)) == ["Parasite", "Lady Bird"])

        importer.applySelected()
        #expect(importer.phase == .done(count: 6))

        let inception = try #require(appModel.titles.first { $0.title == "Inception" })
        #expect(inception.review?.rating == 4.5)
        #expect(inception.review?.text.contains("hallway") == true)
        #expect(
            Calendar.current.component(.year, from: try #require(inception.review?.date)) == 2024,
            "Reviews are dated by when they were watched")

        let matrix = try #require(appModel.titles.first { $0.title == "The Matrix" })
        #expect(matrix.lastWatched != nil)
        #expect(matrix.review?.rating == 4)
    }

    @Test("Ella's own review text is never replaced, and older watch dates don't win")
    func keepsEllasData() async throws {
        let appModel = try await TestSupport.makeAppModel()
        let lakeHouse = try #require(appModel.titles.first { $0.title == "The Lake House" })
        let originalText = try #require(lakeHouse.review?.text)
        let originalWatched = try #require(lakeHouse.lastWatched)

        let importer = LetterboxdImportViewModel(appModel: appModel)
        importer.load(csvFiles: [
            """
            Date,Name,Year,Letterboxd URI,Rating,Rewatch,Review,Tags,Watched Date
            2010-01-01,The Lake House,2006,https://boxd.it/x,3,,Meh.,,2010-01-01
            """
        ])
        importer.applySelected()

        #expect(lakeHouse.review?.text == originalText)
        #expect(lakeHouse.review?.rating == 3, "The rating does update")
        #expect(lakeHouse.lastWatched == originalWatched)
    }
}

@Suite("Watch progress")
@MainActor
struct WatchProgressTests {

    @Test("The watched count follows the Watched check-offs")
    func watchedCount() async throws {
        let appModel = try await TestSupport.makeAppModel()
        #expect(appModel.watchedCount == 11)
        let apollo = try #require(appModel.titles.first { $0.title == "Apollo 13" })
        TitleDetailViewModel(titleID: apollo.persistentModelID, fromTonight: false, appModel: appModel).setWatched(true)
        #expect(appModel.watchedCount == 12)
    }
}

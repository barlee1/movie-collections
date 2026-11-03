//
//  CollectionImporters.swift
//  MovieCollection
//
//  Purpose: Reads collection spreadsheets and Letterboxd exports into rows the
//  import screens can preview before anything is saved.
//  Used in: SpreadsheetImportViewModel, LetterboxdImportViewModel.
//

import Foundation

// MARK: - Shared parsing helpers

nonisolated enum ImportParsing {

    /// Finds a column by any of its accepted header names (case-insensitive).
    static func value(_ record: [String: String], _ names: [String]) -> String? {
        for (header, value) in record where names.contains(header.trimmed.lowercased()) {
            let trimmed = value.trimmed
            if !trimmed.isEmpty { return trimmed }
        }
        return nil
    }

    /// Dates as spreadsheets and Letterboxd write them.
    static func date(_ text: String?) -> Date? {
        guard let text, !text.isEmpty else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        for format in ["yyyy-MM-dd", "M/d/yyyy", "M/d/yy", "MMM d, yyyy", "MMMM d, yyyy"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: text) { return date }
        }
        return nil
    }

    /// Service names as people tend to type them ("Prime", "HBO Max", "Disney Plus").
    static func service(_ text: String?) -> StreamingService? {
        guard let text else { return nil }
        let key = TitleMatcher.normalize(text)
        let aliases: [String: StreamingService] = [
            "plex": .plex,
            "amazon": .amazonPrime, "prime": .amazonPrime, "prime video": .amazonPrime,
            "amazon prime": .amazonPrime, "amazon prime video": .amazonPrime,
            "netflix": .netflix, "hulu": .hulu,
            "max": .max, "hbo max": .max, "hbo": .max,
            "disney": .disneyPlus, "disney plus": .disneyPlus,
            "apple tv": .appleTV, "apple tv plus": .appleTV, "itunes": .appleTV,
            "paramount": .paramountPlus, "paramount plus": .paramountPlus,
            "peacock": .peacock, "movies anywhere": .moviesAnywhere,
            "fandango at home": .fandangoAtHome, "vudu": .fandangoAtHome,
            "youtube": .youTube,
        ]
        // "Disney+" and "Apple TV+" normalize without the plus sign.
        return aliases[key] ?? StreamingService.allCases.first { TitleMatcher.normalize($0.rawValue) == key }
    }

    /// "DVD", "Blu-ray", "Digital", "Streaming", and similar.
    static func format(_ text: String?) -> MediaFormat? {
        guard let text else { return nil }
        let key = TitleMatcher.normalize(text)
        if ["dvd", "blu ray", "bluray", "4k", "physical", "disc"].contains(key) { return .dvd }
        if ["digital", "download", "owned digital"].contains(key) { return .digital }
        if ["streaming", "stream", "subscription"].contains(key) { return .streaming }
        return nil
    }
}

// MARK: - Spreadsheet import

/// One spreadsheet row, ready to preview and add.
nonisolated struct ImportedTitle: Identifiable, Hashable, Sendable {
    let id = UUID()
    var title: String
    var year: Int?
    var kind: TitleKind
    var format: MediaFormat
    var service: StreamingService?
    var filmRating: FilmRating?
    var lastWatched: Date?
    /// Where a disc is, by location name (e.g. "Shelf" or "Basement"). New names become new locations.
    var locationName: String?
    /// Tag names; new ones become new tags.
    var tagNames: [String] = []
    /// The catalog movie this row matched, used to fill in director, cast, and genres.
    var catalogMatch: Movie?
    /// Already on the user's shelf, so it's unchecked by default.
    var isAlreadyOnShelf: Bool
}

nonisolated enum SpreadsheetImporter {

    /// The columns the importer understands, shown on the import screen.
    static let supportedColumns = [
        ("Title", "Required"),
        ("Year", "e.g. 2006"),
        ("Format", "DVD, Digital, or Streaming"),
        ("Service", "e.g. Netflix, Plex"),
        ("Rating", "e.g. PG-13"),
        ("Watched", "A date like 2024-09-25"),
        ("Type", "Movie or TV Show"),
        ("Where", "For discs, e.g. Shelf"),
        ("Tags", "Separated by commas"),
    ]

    struct Result: Sendable {
        var titles: [ImportedTitle]
        /// Rows without a title.
        var skippedRows: Int
    }

    /// Parses a collection spreadsheet.
    /// - Parameters:
    ///   - shelf: The (title, year) pairs already on the shelf, to flag duplicates.
    static func parse(csv: String, catalog: [Movie], shelf: [(title: String, year: Int?)]) -> Result {
        var titles: [ImportedTitle] = []
        var skipped = 0

        for record in CSVParser.parseRecords(csv) {
            guard let title = ImportParsing.value(record, ["title", "name", "movie", "film"]) else {
                skipped += 1
                continue
            }
            let year = ImportParsing.value(record, ["year", "release year"]).flatMap { Int($0.prefix(4)) }
            let match = TitleMatcher.findMovie(title: title, year: year, in: catalog)
            let service = ImportParsing.service(ImportParsing.value(record, ["service", "platform"]))
            let kindText = ImportParsing.value(record, ["type", "kind"]).map(TitleMatcher.normalize)
            let kind: TitleKind = ["tv", "tv show", "show", "series"].contains(kindText ?? "") ? .tvShow : .movie

            titles.append(
                ImportedTitle(
                    title: match?.title ?? title,
                    year: year ?? match?.year,
                    kind: kind,
                    format: ImportParsing.format(ImportParsing.value(record, ["format", "media", "copy"]))
                        ?? inferredFormat(for: service),
                    service: service,
                    filmRating: ImportParsing.value(record, ["rating", "film rating", "mpaa", "certificate"])
                        .flatMap { FilmRating(rawValue: $0.uppercased()) } ?? match?.filmRating,
                    lastWatched: watchedDate(ImportParsing.value(record, ["watched", "last watched", "date watched", "watched date"])),
                    locationName: ImportParsing.value(record, ["where", "stored", "storage", "shelf location", "place"]),
                tagNames: (ImportParsing.value(record, ["tags", "tag", "labels"]) ?? "")
                    .split(separator: ",").map { String($0).cleanedTagName }.filter { !$0.isEmpty },
                catalogMatch: match,
                    isAlreadyOnShelf: shelf.contains { TitleMatcher.isSameTitle($0.title, year: $0.year, as: title, year: year) }
                ))
        }
        return Result(titles: titles, skippedRows: skipped)
    }

    /// With no format given: a subscription-only service means streaming, a
    /// store means a digital copy, and nothing means a disc.
    private static func inferredFormat(for service: StreamingService?) -> MediaFormat {
        guard let service else { return .dvd }
        if MediaFormat.streaming.allowedServices.contains(service), !MediaFormat.digital.allowedServices.contains(service) {
            return .streaming
        }
        return .digital
    }

    /// A date, or "yes"/"x"/"true" meaning watched at some point (recorded as today).
    private static func watchedDate(_ text: String?) -> Date? {
        guard let text else { return nil }
        if let date = ImportParsing.date(text) { return date }
        return ["yes", "y", "x", "true", "watched"].contains(text.lowercased()) ? .now : nil
    }
}

// MARK: - Letterboxd import

/// One film from a Letterboxd export, merged across files.
nonisolated struct LetterboxdEntry: Identifiable, Hashable, Sendable {
    var id: String { "\(TitleMatcher.normalize(name))-\(year.map(String.init) ?? "")" }
    var name: String
    var year: Int?
    /// Letterboxd ratings are already 0.5–5 in half stars.
    var rating: Double?
    /// The most recent watch (or log) date.
    var watchedDate: Date?
    /// Every day it was watched, from diary and review rows (one row per
    /// watch, including rewatches). Oldest first.
    var watchDates: [Date] = []
    var reviewText: String?
}

nonisolated enum LetterboxdImporter {

    /// Reads ratings.csv, diary.csv, reviews.csv, or watched.csv from a
    /// Letterboxd export. Several files can be combined; for each film every
    /// diary watch, the most recent watched date, a rating, and any review
    /// text are kept.
    static func parse(csvFiles: [String]) -> [LetterboxdEntry] {
        var entries: [String: LetterboxdEntry] = [:]
        var order: [String] = []

        for csv in csvFiles {
            for record in CSVParser.parseRecords(csv) {
                guard let name = ImportParsing.value(record, ["name", "title", "film"]) else { continue }
                let year = ImportParsing.value(record, ["year"]).flatMap { Int($0.prefix(4)) }
                // diary and reviews files have a real "Watched Date"; ratings and
                // watched files only have "Date" (when it was logged).
                let diaryWatch = ImportParsing.date(ImportParsing.value(record, ["watched date"]))
                let watched = diaryWatch ?? ImportParsing.date(ImportParsing.value(record, ["date"]))
                let rating = ImportParsing.value(record, ["rating"]).flatMap(Double.init).map(Review.normalized)
                let review = ImportParsing.value(record, ["review"])

                var entry = LetterboxdEntry(name: name, year: year)
                if let existing = entries[entry.id] {
                    entry = existing
                } else {
                    order.append(entry.id)
                }
                if let watched, watched > (entry.watchedDate ?? .distantPast) { entry.watchedDate = watched }
                // The same watch can appear in both diary.csv and reviews.csv.
                if let diaryWatch, !entry.watchDates.contains(where: { Calendar.current.isDate($0, inSameDayAs: diaryWatch) }) {
                    entry.watchDates.append(diaryWatch)
                    entry.watchDates.sort()
                }
                if let rating { entry.rating = rating }
                if let review { entry.reviewText = review }
                entries[entry.id] = entry
            }
        }
        return order.compactMap { entries[$0] }
    }
}

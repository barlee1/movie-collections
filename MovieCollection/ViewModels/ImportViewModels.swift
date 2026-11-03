//
//  ImportViewModels.swift
//  MovieCollection
//
//  Purpose: State for the two file importers on the Add tab: a collection
//  spreadsheet (adds new titles) and a Letterboxd export (updates ratings and
//  watch dates on titles already on the shelf). Both preview first, so
//  nothing is saved until the user confirms.
//  Used in: SpreadsheetImportView, LetterboxdImportView.
//

import Foundation
import Observation
import SwiftData

/// Where an import screen is in its flow.
enum ImportPhase: Equatable {
    /// Picking a file.
    case choosing
    /// Reviewing what will change.
    case preview
    /// Finished; `count` titles were added or updated.
    case done(count: Int)
}

/// Reads a file picked from the Files app (which needs temporary access permission).
nonisolated enum ImportFileReader {
    static func text(from url: URL) throws -> String {
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer { if hasAccess { url.stopAccessingSecurityScopedResource() } }
        let data = try Data(contentsOf: url)
        // Spreadsheet apps often add an invisible byte-order mark at the start.
        return String(decoding: data, as: UTF8.self).replacingOccurrences(of: "\u{FEFF}", with: "")
    }

    /// A sample file bundled with the app, for trying an import without your own file.
    static func bundledSample(named name: String) -> String? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "csv") else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }
}

// MARK: - Spreadsheet

@Observable
final class SpreadsheetImportViewModel {
    private(set) var phase: ImportPhase = .choosing
    private(set) var rows: [ImportedTitle] = []
    private(set) var skippedRows = 0
    /// Rows that will be added. Titles already on the shelf start unchecked.
    var selectedIDs: Set<UUID> = []
    var errorMessage: String?

    private let appModel: AppViewModel

    init(appModel: AppViewModel) {
        self.appModel = appModel
    }

    var selectedCount: Int { selectedIDs.count }

    func load(fileURL: URL) {
        do {
            load(csv: try ImportFileReader.text(from: fileURL))
        } catch {
            errorMessage = "Couldn't open that file: \(error.localizedDescription)"
        }
    }

    func loadSample() {
        guard let csv = ImportFileReader.bundledSample(named: "sample_collection") else {
            errorMessage = "The sample spreadsheet is missing from the app."
            return
        }
        load(csv: csv)
    }

    func load(csv: String) {
        let result = SpreadsheetImporter.parse(
            csv: csv,
            catalog: appModel.catalog,
            shelf: appModel.titles.map { ($0.title, $0.year) }
        )
        guard !result.titles.isEmpty else {
            errorMessage = "No titles found. Make sure the first row has a \"Title\" column."
            return
        }
        rows = result.titles
        skippedRows = result.skippedRows
        selectedIDs = Set(rows.filter { !$0.isAlreadyOnShelf }.map(\.id))
        phase = .preview
        onlineMatching?.cancel()
        onlineMatching = Task { await matchRowsOnline() }
    }

    /// True while rows the bundled catalog didn't recognize are looked up on TMDB.
    private(set) var isMatchingOnline = false
    @ObservationIgnored private var onlineMatching: Task<Void, Never>?

    /// Fills in director, cast, and genres for movie rows the bundled catalog
    /// didn't match, using TMDB. The spreadsheet's own values still win.
    func matchRowsOnline() async {
        guard appModel.hasOnlineCatalog else { return }
        let unmatched = rows.filter { $0.catalogMatch == nil && $0.kind == .movie }
        guard !unmatched.isEmpty else { return }
        isMatchingOnline = true
        defer { isMatchingOnline = false }
        for row in unmatched {
            guard !Task.isCancelled else { return }
            guard let movie = await appModel.lookUpMovie(title: row.title, year: row.year),
                let index = rows.firstIndex(where: { $0.id == row.id })
            else { continue }
            rows[index].catalogMatch = movie
            rows[index].year = rows[index].year ?? movie.year
            rows[index].filmRating = rows[index].filmRating ?? movie.filmRating
        }
    }

    func toggle(_ row: ImportedTitle) {
        selectedIDs.toggle(row.id)
    }

    /// Adds the checked rows to the shelf.
    func importSelected() {
        let chosen = rows.filter { selectedIDs.contains($0.id) }
        var added = 0
        for row in chosen {
            let title = Self.makeOwnedTitle(from: row)
            guard appModel.add(title) else { continue }
            added += 1
            applyPlaceAndTags(from: row, to: title)
        }
        phase = .done(count: added)
    }

    func startOver() {
        onlineMatching?.cancel()
        rows = []
        selectedIDs = []
        skippedRows = 0
        phase = .choosing
    }

    /// Puts a disc in the row's place (making the location if it's new) and adds its tags.
    private func applyPlaceAndTags(from row: ImportedTitle, to title: OwnedTitle) {
        if title.format.isPhysical, let name = row.locationName?.cleanedTagName, !name.isEmpty,
            name.lowercased() != title.storageLocation?.name.lowercased()
        {
            let location = appModel.locations.first { $0.name.lowercased() == name.lowercased() } ?? appModel.addLocation(named: name)
            if let location { appModel.move(title, to: location) }
        }
        let tags = row.tagNames.compactMap { appModel.findOrCreateTag(named: $0) }
        if !tags.isEmpty { appModel.setTags(tags, on: title) }
    }

    /// Catalog matches bring their director, cast, and genres; the spreadsheet's
    /// own format, service, rating, and watched date always win.
    static func makeOwnedTitle(from row: ImportedTitle) -> OwnedTitle {
        let title: OwnedTitle
        if let movie = row.catalogMatch {
            title = OwnedTitle(movie: movie, format: row.format, service: row.service, lastWatched: row.lastWatched)
        } else {
            title = OwnedTitle(
                title: row.title, kind: row.kind, year: row.year, format: row.format,
                service: row.service, lastWatched: row.lastWatched)
        }
        title.kind = row.kind
        title.filmRating = row.filmRating ?? title.filmRating
        return title
    }
}

// MARK: - Letterboxd

/// A Letterboxd film matched to a title on the shelf.
struct LetterboxdMatch: Identifiable {
    let entry: LetterboxdEntry
    let titleID: PersistentIdentifier
    let titleName: String
    var id: String { entry.id }

    /// What will change, e.g. "★ 4.5 · Watched Jan 12, 2024 · Review".
    var summary: String {
        [
            entry.rating.map { "★ \($0.starText)" },
            entry.watchDates.count > 1
                ? "\(entry.watchDates.count) watches, last \(entry.watchedDate?.displayText ?? "")"
                : entry.watchedDate.map { "Watched \($0.displayText)" },
            entry.reviewText == nil ? nil : "Review",
        ]
        .compactMap { $0 }
        .joined(separator: " · ")
    }
}

@Observable
final class LetterboxdImportViewModel {
    private(set) var phase: ImportPhase = .choosing
    private(set) var matches: [LetterboxdMatch] = []
    /// Films in the export that aren't on the shelf (Letterboxd logs everything watched).
    private(set) var unmatched: [LetterboxdEntry] = []
    var selectedIDs: Set<String> = []
    var errorMessage: String?

    private let appModel: AppViewModel

    init(appModel: AppViewModel) {
        self.appModel = appModel
    }

    var selectedCount: Int { selectedIDs.count }

    func load(fileURLs: [URL]) {
        do {
            load(csvFiles: try fileURLs.map(ImportFileReader.text(from:)))
        } catch {
            errorMessage = "Couldn't open that file: \(error.localizedDescription)"
        }
    }

    func loadSample() {
        guard let csv = ImportFileReader.bundledSample(named: "letterboxd_reviews_sample") else {
            errorMessage = "The sample export is missing from the app."
            return
        }
        load(csvFiles: [csv])
    }

    func load(csvFiles: [String]) {
        let entries = LetterboxdImporter.parse(csvFiles: csvFiles)
        guard !entries.isEmpty else {
            errorMessage = "That doesn't look like a Letterboxd export. Choose ratings.csv, diary.csv, or reviews.csv."
            return
        }
        var found: [LetterboxdMatch] = []
        var missing: [LetterboxdEntry] = []
        for entry in entries {
            if let title = appModel.titles.first(where: {
                TitleMatcher.isSameTitle($0.title, year: $0.year, as: entry.name, year: entry.year)
            }) {
                found.append(LetterboxdMatch(entry: entry, titleID: title.persistentModelID, titleName: title.title))
            } else {
                missing.append(entry)
            }
        }
        matches = found
        unmatched = missing
        selectedIDs = Set(found.map(\.id))
        phase = .preview
    }

    func toggle(_ match: LetterboxdMatch) {
        selectedIDs.toggle(match.id)
    }

    /// Updates the checked titles: the Letterboxd rating becomes the user's rating,
    /// every diary watch not already logged is added to the watch history, and
    /// review text fills in only if they haven't written their own.
    func applySelected() {
        var updated = 0
        for match in matches where selectedIDs.contains(match.id) {
            guard let title = appModel.title(with: match.titleID) else { continue }
            let entry = match.entry

            // Diary rows give every watch; ratings and watched files only a date.
            let dates = entry.watchDates.isEmpty ? (entry.watchedDate.map { [$0] } ?? []) : entry.watchDates
            for date in dates where !title.watches.contains(where: { Calendar.current.isDate($0.date, inSameDayAs: date) }) {
                // Without diary rows, only fill in a date for a title never logged.
                if entry.watchDates.isEmpty, title.isWatched, date <= (title.lastWatched ?? .distantPast) { continue }
                appModel.logWatch(of: title, on: date)
            }

            let existingText = title.review?.text ?? ""
            let text = existingText.isEmpty ? (entry.reviewText ?? "") : existingText
            if let rating = entry.rating ?? title.review?.rating, entry.rating != nil || !text.isEmpty {
                // Date the review by when the film was watched on Letterboxd.
                appModel.saveReview(for: title, rating: rating, text: text, date: entry.watchedDate ?? .now)
            }
            updated += 1
        }
        phase = .done(count: updated)
    }

    func startOver() {
        matches = []
        unmatched = []
        selectedIDs = []
        phase = .choosing
    }
}

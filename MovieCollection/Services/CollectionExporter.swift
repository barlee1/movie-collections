//
//  CollectionExporter.swift
//  MovieCollection
//
//  Purpose: Writes the shelf to a CSV file for backup or use in a spreadsheet.
//  The columns match what the spreadsheet importer reads (plus the user's
//  stars and review), so an exported shelf can be imported again.
//  Used in: SettingsView (Data › Export).
//

import Foundation

enum CollectionExporter {

    static let columns = [
        "Title", "Year", "Type", "Format", "Service", "Where", "Rating", "Watched", "Times Watched",
        "My Rating", "Review", "Tags", "Director", "Cast", "Genres",
    ]

    /// The shelf as CSV text, in A to Z order.
    static func csv(for titles: [OwnedTitle]) -> String {
        let rows = ShelfViewModel.sorted(titles, by: .aToZ).map { row(for: $0) }
        return ([columns] + rows).map { $0.map(escape).joined(separator: ",") }.joined(separator: "\n") + "\n"
    }

    /// One title's fields, in the same order as `columns`.
    private static func row(for title: OwnedTitle) -> [String] {
        let watched: String = title.lastWatched.map(dateText) ?? ""
        let timesWatched: String = title.watchCount == 0 ? "" : String(title.watchCount)
        let myRating: String = title.review.map { $0.rating.starText } ?? ""
        let tags: String = title.sortedTags.map(\.name).joined(separator: ", ")
        var fields: [String] = [title.title, title.year.map(String.init) ?? "", title.kind.rawValue, title.format.rawValue]
        fields += [title.service?.rawValue ?? "", title.storageLocation?.name ?? "", title.filmRating?.rawValue ?? ""]
        fields += [watched, timesWatched, myRating, title.review?.text ?? "", tags]
        fields += [title.director, title.cast.joined(separator: ", "), title.genres.joined(separator: ", ")]
        return fields
    }

    /// Writes the CSV to a temporary file named for sharing, e.g. "Rewind Club Shelf 2026-10-27.csv".
    static func exportFile(for titles: [OwnedTitle]) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "Rewind Club Shelf \(dateText(.now)).csv")
        try csv(for: titles).write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    // MARK: - Helpers

    /// Quotes a field when it has a comma, quote, or line break, doubling any quotes.
    nonisolated static func escape(_ field: String) -> String {
        guard field.contains(where: { $0 == "," || $0 == "\"" || $0.isNewline }) else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    /// Dates as yyyy-MM-dd, which the importer reads back.
    private nonisolated static func dateText(_ date: Date) -> String {
        date.formatted(.iso8601.year().month().day())
    }
}

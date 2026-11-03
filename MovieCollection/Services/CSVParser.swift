//
//  CSVParser.swift
//  MovieCollection
//
//  Purpose: A small CSV reader that handles quoted fields, commas and line
//  breaks inside quotes, and doubled quotes ("") as escaped quotes.
//  Used in: MovieCatalogService.
//

import Foundation

nonisolated enum CSVParser {

    /// Splits CSV text into rows of fields. Blank lines are skipped.
    static func parse(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = String.UnicodeScalarView()
        var inQuotes = false

        // Work on unicode scalars so "\r\n" is seen as two separate characters.
        let scalars = Array(text.unicodeScalars)
        var index = 0

        func endField() {
            row.append(String(field))
            field = String.UnicodeScalarView()
        }

        func endRow() {
            endField()
            // Skip lines that are completely empty.
            if !(row.count == 1 && row[0].isEmpty) {
                rows.append(row)
            }
            row = []
        }

        while index < scalars.count {
            let scalar = scalars[index]

            if inQuotes {
                if scalar == "\"" {
                    let nextIsQuote = index + 1 < scalars.count && scalars[index + 1] == "\""
                    if nextIsQuote {
                        // "" inside quotes is a literal quote character.
                        field.append("\"")
                        index += 1
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(scalar)
                }
            } else {
                switch scalar {
                case "\"": inQuotes = true
                case ",": endField()
                case "\n": endRow()
                case "\r": break  // Ignored; "\n" ends the row.
                default: field.append(scalar)
                }
            }
            index += 1
        }

        // The last row may not end with a newline.
        if !field.isEmpty || !row.isEmpty {
            endRow()
        }
        return rows
    }

    /// Parses CSV text with a header row into dictionaries keyed by column name.
    static func parseRecords(_ text: String) -> [[String: String]] {
        let rows = parse(text)
        guard let header = rows.first else { return [] }
        return rows.dropFirst().map { values in
            var record: [String: String] = [:]
            for (column, name) in header.enumerated() where column < values.count {
                record[name] = values[column]
            }
            return record
        }
    }
}

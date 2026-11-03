//
//  TitleMatching.swift
//  MovieCollection
//
//  Purpose: Matching loosely written titles to movies. Spreadsheet rows,
//  Letterboxd exports, and text read off a cover rarely match the catalog
//  character for character, so titles are compared in a normalized form.
//  Used in: SpreadsheetImporter, LetterboxdImporter, the cover scanner.
//

import Foundation

nonisolated enum TitleMatcher {

    /// Lowercased, accents removed, "&" read as "and", punctuation dropped,
    /// spaces collapsed, and a leading "the", "a", or "an" removed.
    /// "The Lord of the Rings: The Return of the King" and
    /// "lord of the rings the return of the king" compare equal.
    static func normalize(_ title: String) -> String {
        let folded =
            title
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US"))
            .replacingOccurrences(of: "&", with: " and ")
        // Turn every non-letter, non-digit into a space, then split into words.
        var cleaned = String.UnicodeScalarView()
        for scalar in folded.unicodeScalars {
            cleaned.append(CharacterSet.alphanumerics.contains(scalar) ? scalar : " ")
        }
        let words = String(cleaned).split(separator: " ").map(String.init)
        let withoutArticle =
            ["the", "a", "an"].contains(words.first ?? "") && words.count > 1
            ? Array(words.dropFirst())
            : words
        return withoutArticle.joined(separator: " ")
    }

    /// The catalog movie with the same title, preferring one released in (or
    /// within a year of) the given year when there's more than one.
    static func findMovie(title: String, year: Int?, in catalog: [Movie]) -> Movie? {
        let key = normalize(title)
        guard !key.isEmpty else { return nil }
        let sameTitle = catalog.filter { normalize($0.title) == key }
        guard let year else { return sameTitle.first }
        return sameTitle.first { abs(($0.year ?? year) - year) <= 1 } ?? (sameTitle.count == 1 ? sameTitle.first : nil)
    }

    /// Whether two titles (and years, when both are known) refer to the same film.
    static func isSameTitle(_ first: String, year firstYear: Int?, as second: String, year secondYear: Int?) -> Bool {
        guard normalize(first) == normalize(second) else { return false }
        guard let firstYear, let secondYear else { return true }
        return abs(firstYear - secondYear) <= 1
    }
}

// MARK: - Cover text

/// Ranks catalog movies against text read off a DVD or Blu-ray case.
nonisolated enum CoverMatcher {

    /// Common words that don't help identify a title on their own.
    private static let fillerWords: Set<String> = ["the", "a", "an", "of", "and", "in", "to", "part", "vol"]

    /// The movies whose titles best match the recognized text, best first.
    ///
    /// Scoring:
    /// - The whole title appearing as a phrase scores highest, and longer
    ///   titles win ties, so "Toy Story 3" beats "Toy Story" when the "3" is there.
    /// - Otherwise, titles with at least two meaningful words score by how many
    ///   of those words appear (at least three quarters must).
    /// - Very short titles ("Up", "Her") only match when they're a line by themselves,
    ///   so a tagline containing "up" doesn't count.
    static func rankMovies(for lines: [String], in catalog: [Movie], limit: Int = 3) -> [Movie] {
        let normalizedLines = lines.map(TitleMatcher.normalize).filter { !$0.isEmpty }
        guard !normalizedLines.isEmpty else { return [] }
        let paddedText = " " + normalizedLines.joined(separator: " ") + " "
        let textWords = Set(paddedText.split(separator: " ").map(String.init))

        let scored: [(movie: Movie, score: Double)] = catalog.compactMap { movie in
            let title = TitleMatcher.normalize(movie.title)
            guard !title.isEmpty else { return nil }

            if title.count < 4 {
                return normalizedLines.contains(title) ? (movie, Double(title.count) * 2) : nil
            }
            if paddedText.contains(" \(title) ") {
                return (movie, Double(title.count) * 2)
            }

            let keyWords = title.split(separator: " ").map(String.init).filter { !fillerWords.contains($0) }
            guard keyWords.count >= 2 else { return nil }
            let found = keyWords.filter(textWords.contains).count
            let fraction = Double(found) / Double(keyWords.count)
            return fraction >= 0.75 ? (movie, Double(title.count) * fraction) : nil
        }

        return
            scored
            .sorted { $0.score > $1.score }
            .prefix(limit)
            .map(\.movie)
    }
}

//
//  MovieCatalogService.swift
//  MovieCollection
//
//  Purpose: Loads the bundled 200-movie catalog (movies_200.csv) off the main
//  thread and turns each row into a Movie.
//  Used in: AppViewModel.
//

import Foundation

nonisolated struct MovieCatalogService: Sendable {

    enum CatalogError: LocalizedError {
        case fileMissing(String)

        var errorDescription: String? {
            switch self {
            case .fileMissing(let name): "The movie catalog \(name) is missing from the app."
            }
        }
    }

    /// The catalog file to read. Defaults to the copy bundled with the app.
    let fileURL: URL?

    init(fileURL: URL? = Bundle.main.url(forResource: "movies_200", withExtension: "csv")) {
        self.fileURL = fileURL
    }

    /// Reads and parses the catalog in the background.
    @concurrent
    func loadMovies() async throws -> [Movie] {
        guard let fileURL else { throw CatalogError.fileMissing("movies_200.csv") }
        let text = try String(contentsOf: fileURL, encoding: .utf8)
        return Self.parseMovies(csv: text)
    }

    /// Converts catalog CSV text into movies, skipping rows without an ID or title.
    /// Expected columns: id, imdb_id, title, genres, overview, release_date,
    /// runtime, director, cast, film_rating. Genres and cast are "|"-separated.
    static func parseMovies(csv: String) -> [Movie] {
        CSVParser.parseRecords(csv).compactMap { record in
            guard let id = Int(record["id"] ?? ""),
                let title = record["title"]?.trimmingCharacters(in: .whitespaces),
                !title.isEmpty
            else { return nil }

            return Movie(
                id: id,
                imdbID: nonEmpty(record["imdb_id"]),
                title: title,
                genres: list(record["genres"]),
                overview: record["overview"] ?? "",
                // release_date is yyyy-MM-dd; only the year is used.
                year: Int((record["release_date"] ?? "").prefix(4)),
                runtime: Int(record["runtime"] ?? ""),
                director: record["director"] ?? "",
                cast: list(record["cast"]),
                filmRating: FilmRating(rawValue: record["film_rating"] ?? "")
            )
        }
    }

    // MARK: - Helpers

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value
    }

    private static func list(_ value: String?) -> [String] {
        (value ?? "")
            .split(separator: "|")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}

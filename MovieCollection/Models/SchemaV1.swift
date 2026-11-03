//
//  SchemaV1.swift
//  MovieCollection
//
//  Purpose: The saved-data models exactly as they were in version 1 (before
//  watch history, locations, and tags). Frozen so SwiftData can read an
//  older store and upgrade it; never change these. The app itself uses the
//  newest version through the typealiases in SchemaVersions.swift.
//  Used in: RewindClubMigrationPlan.
//

import Foundation
import SwiftData

nonisolated enum SchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [OwnedTitle.self, Review.self]
    }

    @Model
    final class OwnedTitle {
        var catalogID: Int?
        var title: String
        var kind: TitleKind
        var genres: [String]
        var overview: String
        var year: Int?
        var runtime: Int?
        var director: String
        var cast: [String]
        var filmRating: FilmRating?
        var imdbID: String?
        var format: MediaFormat
        var service: StreamingService?
        var lastWatched: Date?
        var dateAdded: Date

        @Relationship(deleteRule: .cascade, inverse: \Review.ownedTitle)
        var review: Review?

        init(title: String, format: MediaFormat) {
            self.title = title
            self.kind = .movie
            self.genres = []
            self.overview = ""
            self.director = ""
            self.cast = []
            self.format = format
            self.dateAdded = .now
        }
    }

    @Model
    final class Review {
        var rating: Double
        var text: String
        var date: Date
        var ownedTitle: OwnedTitle?

        init(rating: Double, text: String, date: Date) {
            self.rating = rating
            self.text = text
            self.date = date
        }
    }
}

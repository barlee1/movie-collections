//
//  SchemaV2.swift
//  MovieCollection
//
//  Purpose: The saved-data models exactly as they were in version 2 (watch
//  history, locations, and tags, before family members). Frozen so SwiftData
//  can read an older store and upgrade it; never change these. The app
//  itself uses the newest version through the typealiases in SchemaVersions.swift.
//  Used in: RewindClubMigrationPlan.
//

import Foundation
import SwiftData

nonisolated enum SchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [OwnedTitle.self, Review.self, WatchEvent.self, StorageLocation.self, Tag.self]
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
        var dateAdded: Date

        @Attribute(originalName: "lastWatched")
        var legacyLastWatched: Date?

        @Relationship(deleteRule: .cascade, inverse: \Review.ownedTitle)
        var review: Review?

        @Relationship(deleteRule: .cascade, inverse: \WatchEvent.ownedTitle)
        var watches: [WatchEvent] = []

        var storageLocation: StorageLocation?
        var loanedTo: String?
        var loanedOn: Date?
        var locationBeforeLoanID: UUID?

        var tags: [Tag] = []

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

    @Model
    final class WatchEvent {
        var date: Date
        var note: String
        var ownedTitle: OwnedTitle?

        init(date: Date, note: String) {
            self.date = date
            self.note = note
        }
    }

    @Model
    final class StorageLocation {
        var id: UUID
        var name: String
        var sortOrder: Int
        var role: BuiltInLocation?

        @Relationship(deleteRule: .nullify, inverse: \OwnedTitle.storageLocation)
        var titles: [OwnedTitle] = []

        init(name: String, sortOrder: Int, role: BuiltInLocation?) {
            self.id = UUID()
            self.name = name
            self.sortOrder = sortOrder
            self.role = role
        }
    }

    @Model
    final class Tag {
        var id: UUID
        var name: String
        var colorIndex: Int

        @Relationship(deleteRule: .nullify, inverse: \OwnedTitle.tags)
        var titles: [OwnedTitle] = []

        init(name: String, colorIndex: Int) {
            self.id = UUID()
            self.name = name
            self.colorIndex = colorIndex
        }
    }
}

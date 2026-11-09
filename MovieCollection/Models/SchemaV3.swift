//
//  SchemaV3.swift
//  MovieCollection
//
//  Purpose: The saved-data models exactly as they were in version 3 (family
//  members, before loan return dates). Frozen so SwiftData can read an older
//  store and upgrade it; never change these. The app itself uses the newest
//  version through the typealiases in SchemaVersions.swift.
//  Used in: RewindClubMigrationPlan.
//

import Foundation
import SwiftData

nonisolated enum SchemaV3: VersionedSchema {
    static let versionIdentifier = Schema.Version(3, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            OwnedTitle.self, Review.self, WatchEvent.self, StorageLocation.self, Tag.self,
            FamilyMember.self, FamilyRating.self,
        ]
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

        @Relationship(deleteRule: .cascade, inverse: \FamilyRating.ownedTitle)
        var familyRatings: [FamilyRating] = []

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
        var viewers: [FamilyMember] = []

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

    @Model
    final class FamilyMember {
        var id: UUID
        var name: String
        var age: Int?
        var colorIndex: Int
        var sortOrder: Int

        @Relationship(deleteRule: .cascade, inverse: \FamilyRating.member)
        var ratings: [FamilyRating] = []

        @Relationship(deleteRule: .nullify, inverse: \WatchEvent.viewers)
        var watches: [WatchEvent] = []

        init(name: String, age: Int?, colorIndex: Int, sortOrder: Int) {
            self.id = UUID()
            self.name = name
            self.age = age
            self.colorIndex = colorIndex
            self.sortOrder = sortOrder
        }
    }

    @Model
    final class FamilyRating {
        var rating: Double?
        var markedSeen: Bool
        var member: FamilyMember?
        var ownedTitle: OwnedTitle?

        init(rating: Double?, markedSeen: Bool) {
            self.rating = rating
            self.markedSeen = markedSeen
        }
    }
}

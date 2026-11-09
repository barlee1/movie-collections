//
//  SchemaVersions.swift
//  MovieCollection
//
//  Purpose: Versions of the saved shelf data, so app updates can upgrade a
//  tester's existing shelf instead of losing it. Each version keeps its own
//  copies of the model classes; the rest of the app uses the typealiases
//  below, which always point at the newest version.
//  Used in: CollectionStore.makeContainer.
//
//  Adding a version later:
//  1. Freeze the current models: copy them into SchemaV4.swift-style frozen
//     copies (like SchemaV1.swift through SchemaV3.swift), stored properties only.
//  2. Make the changes in a new SchemaV5 and point the typealiases at it.
//  3. Add SchemaV5 to `RewindClubMigrationPlan.schemas` and a stage to `stages`.
//

import Foundation
import SwiftData

/// The newest saved-data models. Update these when a new schema version is added.
typealias OwnedTitle = SchemaV4.OwnedTitle
typealias Review = SchemaV4.Review
typealias WatchEvent = SchemaV4.WatchEvent
typealias StorageLocation = SchemaV4.StorageLocation
typealias Tag = SchemaV4.Tag
typealias FamilyMember = SchemaV4.FamilyMember
typealias FamilyRating = SchemaV4.FamilyRating

/// Version 4 adds a return date for loaned discs (`OwnedTitle.loanDueOn`).
/// Version 3 added family members, who was at each watch, and family ratings.
/// The models live in OwnedTitle.swift, Review.swift, WatchEvent.swift,
/// StorageLocation.swift, Tag.swift, and FamilyMember.swift.
nonisolated enum SchemaV4: VersionedSchema {
    static let versionIdentifier = Schema.Version(4, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            OwnedTitle.self, Review.self, WatchEvent.self, StorageLocation.self, Tag.self,
            FamilyMember.self, FamilyRating.self,
        ]
    }
}

/// How to upgrade saved data between schema versions, oldest first.
nonisolated enum RewindClubMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self, SchemaV3.self, SchemaV4.self]
    }

    /// Version 1 to 2 only adds tables and optional fields, and renames
    /// `lastWatched` to `legacyLastWatched`, so SwiftData can do it on its own.
    /// Turning that old date into a watch event and putting DVDs on the Shelf
    /// happens in `CollectionStore.upgradeLegacyData()` at launch.
    /// Version 2 to 3 only adds the family tables and empty relationships.
    static var stages: [MigrationStage] {
        [
            .lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self),
            .lightweight(fromVersion: SchemaV2.self, toVersion: SchemaV3.self),
            // Version 3 to 4 only adds one optional date.
            .lightweight(fromVersion: SchemaV3.self, toVersion: SchemaV4.self),
        ]
    }
}

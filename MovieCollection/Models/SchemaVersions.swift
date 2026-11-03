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
//  1. Freeze the current models: copy them into SchemaV2.swift-style frozen
//     copies (like SchemaV1.swift), stored properties only.
//  2. Make the changes in a new SchemaV3 and point the typealiases at it.
//  3. Add SchemaV3 to `RewindClubMigrationPlan.schemas` and a stage to `stages`.
//

import Foundation
import SwiftData

/// The newest saved-data models. Update these when a new schema version is added.
typealias OwnedTitle = SchemaV2.OwnedTitle
typealias Review = SchemaV2.Review
typealias WatchEvent = SchemaV2.WatchEvent
typealias StorageLocation = SchemaV2.StorageLocation
typealias Tag = SchemaV2.Tag

/// Version 2 adds watch history, physical locations, and tags.
/// The models live in OwnedTitle.swift, Review.swift, WatchEvent.swift,
/// StorageLocation.swift, and Tag.swift.
nonisolated enum SchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [OwnedTitle.self, Review.self, WatchEvent.self, StorageLocation.self, Tag.self]
    }
}

/// How to upgrade saved data between schema versions, oldest first.
nonisolated enum RewindClubMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self]
    }

    /// Version 1 to 2 only adds tables and optional fields, and renames
    /// `lastWatched` to `legacyLastWatched`, so SwiftData can do it on its own.
    /// Turning that old date into a watch event and putting DVDs on the Shelf
    /// happens in `CollectionStore.upgradeLegacyData()` at launch.
    static var stages: [MigrationStage] {
        [.lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self)]
    }
}

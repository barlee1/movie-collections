//
//  StorageLocation.swift
//  MovieCollection
//
//  Purpose: A place a physical copy can be, like "Shelf", "Loaned out", or a
//  custom one such as "Living room cabinet". Shelf and Loaned out are built
//  in: they can be renamed but not deleted, since the app relies on them.
//  Used in: OwnedTitle, CollectionStore, the edit and add forms, Settings › Locations.
//  Part of SchemaV4 (see SchemaVersions.swift); the app uses the StorageLocation typealias.
//

import Foundation
import SwiftData

/// The two locations every shelf has.
nonisolated enum BuiltInLocation: String, Codable, CaseIterable, Sendable {
    case shelf
    case loanedOut

    var defaultName: String {
        switch self {
        case .shelf: "Shelf"
        case .loanedOut: "Loaned out"
        }
    }
}

extension SchemaV4 {
    @Model
    final class StorageLocation {
        /// Stable across renames, so a loaned disc remembers where to go back to.
        var id: UUID
        var name: String
        /// Position in pickers and Settings › Locations, lowest first.
        var sortOrder: Int
        /// Set for Shelf and Loaned out; nil for locations the user made.
        var role: BuiltInLocation?

        @Relationship(deleteRule: .nullify, inverse: \OwnedTitle.storageLocation)
        var titles: [OwnedTitle] = []

        init(name: String, sortOrder: Int, role: BuiltInLocation? = nil) {
            self.id = UUID()
            self.name = name
            self.sortOrder = sortOrder
            self.role = role
        }

        var isBuiltIn: Bool { role != nil }
    }
}

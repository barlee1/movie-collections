//
//  Tag.swift
//  MovieCollection
//
//  Purpose: A label the user makes, like "Christmas", "Comfort movie", or
//  "Date night". A title can have any number of tags. Names are unique,
//  ignoring capitals (CollectionStore enforces this).
//  Used in: OwnedTitle, CollectionStore, detail, forms, filters, Tonight, Settings › Tags.
//  Part of SchemaV4 (see SchemaVersions.swift); the app uses the Tag typealias.
//

import Foundation
import SwiftData

extension SchemaV4 {
    @Model
    final class Tag {
        var id: UUID
        var name: String
        /// Which theme color the tag's chip uses; see `TagPalette`.
        var colorIndex: Int

        @Relationship(deleteRule: .nullify, inverse: \OwnedTitle.tags)
        var titles: [OwnedTitle] = []

        init(name: String, colorIndex: Int = 0) {
            self.id = UUID()
            self.name = name
            self.colorIndex = colorIndex
        }
    }
}

extension String {
    /// A tag name as typed, trimmed and with runs of spaces collapsed.
    nonisolated var cleanedTagName: String {
        split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}

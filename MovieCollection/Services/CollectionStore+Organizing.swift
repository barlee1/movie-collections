//
//  CollectionStore+Organizing.swift
//  MovieCollection
//
//  Purpose: Reading and writing watch history, physical locations, and tags,
//  plus the one-time upgrade of version 1 data (each old "last watched"
//  date becomes the first watch, and every DVD goes on the Shelf).
//  Used in: AppViewModel, ShelfSeeder, importers.
//

import Foundation
import SwiftData

extension CollectionStore {

    // MARK: - Upgrading older data

    /// Makes sure Shelf and Loaned out exist, turns leftover single watched
    /// dates into watch events, and puts unplaced DVDs on the Shelf.
    /// Safe to run every launch; it only changes what still needs it.
    func upgradeLegacyData() throws {
        _ = try builtInLocation(.shelf)
        _ = try builtInLocation(.loanedOut)
        for title in try allTitles() {
            try settleLegacyFields(of: title)
        }
        if context.hasChanges { try context.save() }
    }

    /// The upgrade for one title. Doesn't save.
    func settleLegacyFields(of title: OwnedTitle) throws {
        if let date = title.legacyLastWatched {
            if title.watches.isEmpty {
                addWatchEvent(to: title, date: date)
            }
            title.legacyLastWatched = nil
        }
        try settleLocation(of: title)
    }

    /// A disc without a place goes on the Shelf; digital and streaming
    /// copies don't have a physical place. Doesn't save.
    func settleLocation(of title: OwnedTitle) throws {
        if title.format.isPhysical {
            if title.storageLocation == nil {
                title.storageLocation = try builtInLocation(.shelf)
            }
        } else {
            title.storageLocation = nil
            title.loanedTo = nil
            title.loanedOn = nil
            title.locationBeforeLoanID = nil
        }
    }

    // MARK: - Watch history

    /// Logs a watch on the given date.
    @discardableResult
    func logWatch(of title: OwnedTitle, on date: Date, note: String = "") throws -> WatchEvent {
        let watch = addWatchEvent(to: title, date: date, note: note)
        try context.save()
        return watch
    }

    func updateWatch(_ watch: WatchEvent, date: Date, note: String) throws {
        watch.date = date
        watch.note = note
        try context.save()
    }

    func deleteWatch(_ watch: WatchEvent) throws {
        watch.ownedTitle?.watches.removeAll { $0 === watch }
        context.delete(watch)
        try context.save()
    }

    /// Removes every watch of a title (unchecking "Watched").
    func clearWatches(of title: OwnedTitle) throws {
        let watches = title.watches
        title.watches = []
        title.legacyLastWatched = nil
        for watch in watches { context.delete(watch) }
        try context.save()
    }

    @discardableResult
    private func addWatchEvent(to title: OwnedTitle, date: Date, note: String = "") -> WatchEvent {
        let watch = WatchEvent(date: date, note: note)
        context.insert(watch)
        title.watches.append(watch)
        return watch
    }

    // MARK: - Locations

    /// Every location, in the user's order.
    func allLocations() throws -> [StorageLocation] {
        try context.fetch(FetchDescriptor<StorageLocation>(sortBy: [SortDescriptor(\.sortOrder)]))
    }

    /// Shelf or Loaned out, created the first time it's needed.
    func builtInLocation(_ role: BuiltInLocation) throws -> StorageLocation {
        let locations = try allLocations()
        if let existing = locations.first(where: { $0.role == role }) { return existing }
        let location = StorageLocation(
            name: role.defaultName,
            sortOrder: role == .shelf ? -2 : -1,
            role: role
        )
        context.insert(location)
        return location
    }

    @discardableResult
    func addLocation(named name: String) throws -> StorageLocation {
        let next = (try allLocations().map(\.sortOrder).max() ?? 0) + 1
        let location = StorageLocation(name: name, sortOrder: next)
        context.insert(location)
        try context.save()
        return location
    }

    func renameLocation(_ location: StorageLocation, to name: String) throws {
        location.name = name
        try context.save()
    }

    /// Saves a new order, e.g. after dragging in Settings › Locations.
    func reorderLocations(_ locations: [StorageLocation]) throws {
        for (index, location) in locations.enumerated() {
            location.sortOrder = index
        }
        try context.save()
    }

    /// Deletes a custom location. Its discs move to the Shelf. Built-in ones can't be deleted.
    func deleteLocation(_ location: StorageLocation) throws {
        guard !location.isBuiltIn else { return }
        let shelf = try builtInLocation(.shelf)
        for title in location.titles {
            title.storageLocation = shelf
        }
        // Loaned discs that were going back here go back to the Shelf instead.
        for title in try allTitles() where title.locationBeforeLoanID == location.id {
            title.locationBeforeLoanID = shelf.id
        }
        context.delete(location)
        try context.save()
    }

    /// Moves a disc somewhere else. Moving it to Loaned out records who has
    /// it and when, and remembers where it came from.
    func move(_ title: OwnedTitle, to location: StorageLocation, loanedTo borrower: String? = nil, on date: Date = .now) throws {
        if location.role == .loanedOut {
            if !title.isLoanedOut {
                title.locationBeforeLoanID = title.storageLocation?.id
            }
            title.loanedTo = borrower?.trimmed.isEmpty == false ? borrower?.trimmed : nil
            title.loanedOn = date
        } else {
            title.loanedTo = nil
            title.loanedOn = nil
            title.locationBeforeLoanID = nil
        }
        title.storageLocation = location
        try context.save()
    }

    /// Brings a loaned disc back to where it was before (or the Shelf).
    func markReturned(_ title: OwnedTitle) throws {
        let locations = try allLocations()
        let previous = locations.first { $0.id == title.locationBeforeLoanID && $0.role != .loanedOut }
        try move(title, to: previous ?? builtInLocation(.shelf))
    }

    // MARK: - Tags

    /// Every tag, A to Z.
    func allTags() throws -> [Tag] {
        try context.fetch(FetchDescriptor<Tag>()).sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    /// The tag with this name, ignoring capitals, if there is one.
    func tag(named name: String) throws -> Tag? {
        let key = name.cleanedTagName.lowercased()
        return try allTags().first { $0.name.lowercased() == key }
    }

    /// Finds the tag with this name (ignoring capitals) or makes a new one,
    /// so the same tag is never created twice. Returns nil for a blank name.
    @discardableResult
    func findOrCreateTag(named name: String) throws -> Tag? {
        let cleaned = name.cleanedTagName
        guard !cleaned.isEmpty else { return nil }
        if let existing = try tag(named: cleaned) { return existing }
        let tag = Tag(name: cleaned, colorIndex: try allTags().count % TagPalette.count)
        context.insert(tag)
        try context.save()
        return tag
    }

    func setTags(_ tags: [Tag], on title: OwnedTitle) throws {
        title.tags = tags
        try context.save()
    }

    /// Renames a tag. Renaming to another tag's name merges the two instead.
    func renameTag(_ tag: Tag, to name: String) throws {
        let cleaned = name.cleanedTagName
        guard !cleaned.isEmpty else { return }
        if let other = try self.tag(named: cleaned), other !== tag {
            try mergeTag(tag, into: other)
        } else {
            tag.name = cleaned
            try context.save()
        }
    }

    func recolorTag(_ tag: Tag, colorIndex: Int) throws {
        tag.colorIndex = colorIndex
        try context.save()
    }

    /// Moves every title from one tag to another, then deletes the first.
    func mergeTag(_ source: Tag, into target: Tag) throws {
        guard source !== target else { return }
        for title in source.titles where !title.tags.contains(where: { $0 === target }) {
            title.tags.append(target)
        }
        context.delete(source)
        try context.save()
    }

    /// Deletes a tag. Titles keep everything else; they just lose the tag.
    func deleteTag(_ tag: Tag) throws {
        context.delete(tag)
        try context.save()
    }

    // MARK: - Deleting everything

    /// Removes every title, tag, and custom location. Shelf and Loaned out stay.
    func deleteAllData() throws {
        for title in try allTitles() { context.delete(title) }
        for tag in try allTags() { context.delete(tag) }
        for location in try allLocations() where !location.isBuiltIn { context.delete(location) }
        try context.save()
    }
}

extension MediaFormat {
    /// DVDs (and Blu-rays) have a physical place; digital and streaming don't.
    nonisolated var isPhysical: Bool { self == .dvd }
}

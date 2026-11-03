//
//  AppViewModel+Organizing.swift
//  MovieCollection
//
//  Purpose: The app-wide actions for watch history, physical locations, and
//  tags. Each one saves through CollectionStore and refreshes the shelf, so
//  every screen updates; a failure shows the usual error alert.
//  Used in: Detail, forms, importers, Settings › Locations and Tags.
//

import Foundation

extension AppViewModel {

    // MARK: - Watch history

    @discardableResult
    func logWatch(of title: OwnedTitle, on date: Date = .now, note: String = "") -> Bool {
        perform("log that watch") { try store.logWatch(of: title, on: min(date, .now), note: note) }
    }

    @discardableResult
    func updateWatch(_ watch: WatchEvent, date: Date, note: String) -> Bool {
        perform("update that watch") { try store.updateWatch(watch, date: min(date, .now), note: note) }
    }

    @discardableResult
    func deleteWatch(_ watch: WatchEvent) -> Bool {
        perform("remove that watch") { try store.deleteWatch(watch) }
    }

    /// Removes every watch of a title, so it's "not watched yet" again.
    @discardableResult
    func clearWatches(of title: OwnedTitle) -> Bool {
        perform("clear the watch history") { try store.clearWatches(of: title) }
    }

    // MARK: - Locations

    /// Changes how the user has a title. A disc gets a place; digital and streaming lose theirs.
    @discardableResult
    func updateFormat(of title: OwnedTitle, format: MediaFormat, service: StreamingService?) -> Bool {
        perform("save \(title.title)") { try store.updateFormat(of: title, format: format, service: service) }
    }

    func location(_ role: BuiltInLocation) -> StorageLocation? {
        locations.first { $0.role == role }
    }

    @discardableResult
    func addLocation(named name: String) -> StorageLocation? {
        let cleaned = name.cleanedTagName
        guard !cleaned.isEmpty else { return nil }
        var added: StorageLocation?
        _ = perform("add that location") { added = try store.addLocation(named: cleaned) }
        return added
    }

    @discardableResult
    func renameLocation(_ location: StorageLocation, to name: String) -> Bool {
        let cleaned = name.cleanedTagName
        guard !cleaned.isEmpty else { return false }
        return perform("rename that location") { try store.renameLocation(location, to: cleaned) }
    }

    @discardableResult
    func reorderLocations(_ ordered: [StorageLocation]) -> Bool {
        perform("reorder your locations") { try store.reorderLocations(ordered) }
    }

    @discardableResult
    func deleteLocation(_ location: StorageLocation) -> Bool {
        perform("delete that location") { try store.deleteLocation(location) }
    }

    /// Moves a disc. Loaned out records who has it and since when.
    @discardableResult
    func move(_ title: OwnedTitle, to location: StorageLocation, loanedTo borrower: String? = nil, on date: Date = .now) -> Bool {
        perform("move \(title.title)") { try store.move(title, to: location, loanedTo: borrower, on: date) }
    }

    @discardableResult
    func markReturned(_ title: OwnedTitle) -> Bool {
        perform("mark \(title.title) returned") { try store.markReturned(title) }
    }

    /// Titles currently loaned out, oldest loan first.
    var loanedOutTitles: [OwnedTitle] {
        titles.filter(\.isLoanedOut).sorted { ($0.loanedOn ?? .distantPast) < ($1.loanedOn ?? .distantPast) }
    }

    // MARK: - Tags

    /// The tag with this name (ignoring capitals), made new if needed.
    @discardableResult
    func findOrCreateTag(named name: String) -> Tag? {
        var found: Tag?
        _ = perform("add that tag") { found = try store.findOrCreateTag(named: name) }
        return found
    }

    @discardableResult
    func setTags(_ tags: [Tag], on title: OwnedTitle) -> Bool {
        perform("save the tags") { try store.setTags(tags, on: title) }
    }

    /// Renaming to an existing tag's name merges the two.
    @discardableResult
    func renameTag(_ tag: Tag, to name: String) -> Bool {
        perform("rename that tag") { try store.renameTag(tag, to: name) }
    }

    @discardableResult
    func recolorTag(_ tag: Tag, colorIndex: Int) -> Bool {
        perform("change that tag's color") { try store.recolorTag(tag, colorIndex: colorIndex) }
    }

    @discardableResult
    func mergeTag(_ source: Tag, into target: Tag) -> Bool {
        perform("merge those tags") { try store.mergeTag(source, into: target) }
    }

    @discardableResult
    func deleteTag(_ tag: Tag) -> Bool {
        perform("delete that tag") { try store.deleteTag(tag) }
    }
}

//
//  TitleDetailViewModel.swift
//  MovieCollection
//
//  Purpose: Display values and quick actions for one title's detail screen:
//  watched and reviewed check-offs, watch history, tags, and where a disc is.
//  Used in: TitleDetailView.
//

import Foundation
import Observation
import SwiftData

@Observable
final class TitleDetailViewModel {
    let titleID: PersistentIdentifier
    /// Opened from Tonight: shows "Tonight's pick" and "Pick another".
    let fromTonight: Bool
    var isEditing = false
    /// True when the sheet was opened from "Write a review".
    private(set) var editStartsWithReview = false

    func startEditing(writingReview: Bool = false) {
        editStartsWithReview = writingReview
        isEditing = true
    }

    let appModel: AppViewModel

    init(titleID: PersistentIdentifier, fromTonight: Bool, appModel: AppViewModel) {
        self.titleID = titleID
        self.fromTonight = fromTonight
        self.appModel = appModel
    }

    /// The title, or nil if it has been removed from the shelf.
    var title: OwnedTitle? { appModel.title(with: titleID) }

    // MARK: - Quick check-offs (no Edit sheet needed)

    /// The rating a quick "Reviewed" check starts with, before the user adjusts the stars.
    static let quickReviewRating = 3.0

    /// Shown before unchecking "Reviewed" would delete written review text.
    var isConfirmingReviewRemoval = false

    var isWatched: Bool { title?.isWatched ?? false }
    var isReviewed: Bool { title?.isReviewed ?? false }
    var rating: Double { title?.review?.rating ?? 0 }

    /// Shown before unchecking "Watched" would remove more than one watch.
    var isConfirmingWatchClear = false

    /// Checking logs a watch today (the one-tap check-off). Unchecking removes
    /// the watch history, asking first if there's more than one watch.
    func setWatched(_ watched: Bool) {
        guard let title, watched != isWatched else { return }
        if watched {
            appModel.logWatch(of: title)
        } else if title.watchCount > 1 {
            isConfirmingWatchClear = true
        } else {
            appModel.clearWatches(of: title)
        }
    }

    /// Removes every watch after the user confirms.
    func confirmWatchClear() {
        guard let title else { return }
        appModel.clearWatches(of: title)
    }

    // MARK: - Watch history

    /// The watch being edited in the watch sheet, or nil when logging a new one.
    private(set) var editingWatch: WatchEvent?
    var isShowingWatchSheet = false

    func startLoggingWatch() {
        editingWatch = nil
        isShowingWatchSheet = true
    }

    func startEditing(_ watch: WatchEvent) {
        editingWatch = watch
        isShowingWatchSheet = true
    }

    /// Saves the watch sheet: a new watch, or changes to the one being edited.
    func saveWatch(date: Date, note: String) {
        guard let title else { return }
        if let editingWatch {
            appModel.updateWatch(editingWatch, date: date, note: note)
        } else {
            appModel.logWatch(of: title, on: date, note: note)
        }
    }

    func deleteWatch(_ watch: WatchEvent) {
        appModel.deleteWatch(watch)
    }

    /// History rows newest first, numbered oldest first: "3rd watch", "2nd watch", "1st watch".
    struct WatchRow: Identifiable {
        let watch: WatchEvent
        let label: String
        var id: PersistentIdentifier { watch.persistentModelID }
    }

    var watchRows: [WatchRow] {
        guard let title else { return [] }
        let newestFirst = title.sortedWatches
        return newestFirst.enumerated().map { offset, watch in
            WatchRow(watch: watch, label: "\(WatchHistoryText.ordinal(newestFirst.count - offset)) watch")
        }
    }

    // MARK: - Tags and location

    var isPickingTags = false
    var isMovingDisc = false

    func setTags(_ tags: [Tag]) {
        guard let title else { return }
        appModel.setTags(tags, on: title)
    }

    func markReturned() {
        guard let title else { return }
        appModel.markReturned(title)
    }

    /// Checking creates a review the user can rate right away. Unchecking removes it,
    /// asking first if she wrote any text.
    func setReviewed(_ reviewed: Bool) {
        guard let title, reviewed != isReviewed else { return }
        if reviewed {
            appModel.saveReview(for: title, rating: Self.quickReviewRating, text: "")
        } else if let text = title.review?.text, !text.isEmpty {
            isConfirmingReviewRemoval = true
        } else {
            appModel.deleteReview(for: title)
        }
    }

    /// Removes the review after the user confirms.
    func confirmReviewRemoval() {
        guard let title else { return }
        appModel.deleteReview(for: title)
    }

    /// Shows the review-only note sheet.
    var isWritingNote = false

    /// The current review note, or empty.
    var reviewNote: String { title?.review?.text ?? "" }

    /// Saves the rating and note from the note sheet.
    func saveNote(rating: Double, note: String) {
        guard let title else { return }
        appModel.saveReview(for: title, rating: rating, text: note)
    }

    /// Updates the star rating from the inline picker, keeping any written text.
    func setRating(_ rating: Double) {
        guard let title, let review = title.review, rating != review.rating else { return }
        appModel.saveReview(for: title, rating: rating, text: review.text)
    }

    // MARK: - Display values

    struct InfoRow: Identifiable {
        let label: String
        let value: String
        var id: String { label }
    }

    /// The bold-label lines under the location: title, rating, director, year, cast.
    var infoRows: [InfoRow] {
        guard let title else { return [] }
        return [InfoRow(label: "Title", value: title.title)] + Self.detailRows(for: title)
    }

    /// Rating, director, year, and cast. Shared with the back of the flip cards.
    static func detailRows(for title: OwnedTitle) -> [InfoRow] {
        [
            InfoRow(label: "Rating", value: title.filmRating?.label ?? "Not set"),
            InfoRow(label: title.kind.directorLabel, value: title.director.isEmpty ? "Unknown" : title.director),
            InfoRow(label: "Year", value: title.year.map(String.init) ?? "Unknown"),
            InfoRow(label: "Cast", value: title.cast.isEmpty ? "Unknown" : title.cast.joined(separator: ", ")),
        ]
    }

    /// "Last watched Sep 25, 2024", "Last watched Oct 21, 2026 · 3 times", or "Not watched yet".
    static func watchedLabel(for title: OwnedTitle) -> String {
        guard let date = title.lastWatched else { return "Not watched yet" }
        let count = title.watchCount
        return count > 1 ? "Last watched \(date.displayText) · \(count) times" : "Last watched \(date.displayText)"
    }

    /// Where a disc physically is: "Shelf", "Living room cabinet", or
    /// "Loaned to Sam since Oct 3, 2026". Nil for digital and streaming.
    static func placeText(for title: OwnedTitle) -> String? {
        guard title.format.isPhysical, let location = title.storageLocation else { return nil }
        guard location.role == .loanedOut else { return location.name }
        let who = title.loanedTo.map { "Loaned to \($0)" } ?? location.name
        return title.loanedOn.map { "\(who) since \($0.displayText)" } ?? who
    }

    var watchedLabel: String {
        guard let title else { return "" }
        return Self.watchedLabel(for: title)
    }

    var locationNote: String {
        guard let title else { return "" }
        return title.format.note(service: title.service)
    }
}

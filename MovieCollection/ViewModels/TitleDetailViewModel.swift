//
//  TitleDetailViewModel.swift
//  MovieCollection
//
//  Purpose: Display values and quick actions for one title's detail screen:
//  watched and reviewed check-offs, watch history, tags, where a disc is,
//  who in the family has seen it (with their own ratings), and for streaming
//  titles, ways to own it instead.
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

    /// Saves the watch sheet: a new watch, or changes to the one being edited,
    /// with the family members who were there.
    func saveWatch(date: Date, note: String, viewers: [FamilyMember]) {
        guard let title else { return }
        if let editingWatch {
            appModel.updateWatch(editingWatch, date: date, note: note, viewers: viewers)
        } else {
            appModel.logWatch(of: title, on: date, note: note, viewers: viewers)
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

    /// "with Sam and Riley", or nil if no family member was marked as there.
    static func viewersText(for watch: WatchEvent) -> String? {
        let names = watch.viewers.sorted { $0.sortOrder < $1.sortOrder }.map(\.name)
        guard !names.isEmpty else { return nil }
        return "with " + names.formatted(.list(type: .and))
    }

    // MARK: - Family

    /// One family member's row: seen or not, their last watch, and their stars.
    struct FamilyRow: Identifiable {
        let member: FamilyMember
        let hasSeen: Bool
        let detail: String
        let rating: Double?
        var id: UUID { member.id }
    }

    var familyRows: [FamilyRow] {
        guard let title else { return [] }
        return appModel.familyMembers.map { member in
            FamilyRow(
                member: member,
                hasSeen: title.hasBeenSeen(by: member),
                detail: Self.familyDetail(for: member, title: title),
                rating: title.familyRating(for: member)
            )
        }
    }

    /// "Last watched Oct 21, 2026 · 2 times", "Seen", or "Not seen yet".
    static func familyDetail(for member: FamilyMember, title: OwnedTitle) -> String {
        guard title.hasBeenSeen(by: member) else { return "Not seen yet" }
        guard let date = title.lastWatched(by: member) else { return "Seen" }
        let count = title.watches(seenBy: member).count
        return count > 1 ? "Last watched \(date.displayText) · \(count) times" : "Last watched \(date.displayText)"
    }

    /// "Not seen by: Sam, Riley", "Everyone has seen it", or nil with no family.
    var familySummary: String? {
        guard let title, appModel.hasFamily else { return nil }
        let notSeen = appModel.names(notSeen: title)
        return notSeen.isEmpty ? "Everyone has seen it" : "Not seen by: \(notSeen.joined(separator: ", "))"
    }

    /// Set before unchecking someone who was at logged watches or rated it.
    var confirmingUnseen: FamilyMember?

    /// Checking marks them seen. Unchecking clears their rating and takes them
    /// off this title's watches, asking first if that loses anything.
    func setSeen(_ seen: Bool, by member: FamilyMember) {
        guard let title, seen != title.hasBeenSeen(by: member) else { return }
        if !seen, !title.watches(seenBy: member).isEmpty || title.familyRating(for: member) != nil {
            confirmingUnseen = member
        } else {
            appModel.setSeen(seen, by: member, title: title)
        }
    }

    func confirmUnseen() {
        guard let title, let member = confirmingUnseen else { return }
        appModel.setSeen(false, by: member, title: title)
        confirmingUnseen = nil
    }

    /// e.g. "Sam's rating and 2 watches will be cleared."
    var unseenMessage: String {
        guard let title, let member = confirmingUnseen else { return "" }
        let watches = title.watches(seenBy: member).count
        var parts: [String] = []
        if title.familyRating(for: member) != nil { parts.append("their rating is cleared") }
        if watches > 0 { parts.append("they come off \(watches) logged \(watches == 1 ? "watch" : "watches")") }
        let sentence = parts.joined(separator: ", and ")
        return sentence.prefix(1).uppercased() + sentence.dropFirst() + "."
    }

    func setFamilyRating(_ rating: Double?, by member: FamilyMember) {
        guard let title, rating != title.familyRating(for: member) else { return }
        appModel.setFamilyRating(rating, by: member, title: title)
    }

    // MARK: - Own it instead

    enum OwnItState: Equatable {
        case loading
        /// Where-to-buy data from TMDB.
        case known(PurchaseOptions)
        /// No data (no TMDB key, offline, a TV show, or a hand-entered title): search links only.
        case unknown
    }

    private(set) var ownItState: OwnItState = .loading

    /// Streaming titles get the card, unless it's turned off in Settings.
    var showsOwnItInstead: Bool {
        title?.format == .streaming && appModel.showsOwnItSuggestions
    }

    func loadOwnItInstead() async {
        guard let title, showsOwnItInstead else { return }
        ownItState = .loading
        ownItState = await appModel.purchaseOptions(for: title).map(OwnItState.known) ?? .unknown
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

    /// e.g. "Romance, Drama · 1h 39m", or nil with neither.
    var genreAndRuntime: String? {
        guard let title else { return nil }
        let parts = [
            title.genres.isEmpty ? nil : title.genres.prefix(3).joined(separator: ", "),
            title.runtime.map(TitleDisplay.runtimeText(minutes:)),
        ].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// Rating, director, year, and cast.
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

    /// "Due back Nov 23, 2026" or "Overdue since Nov 23, 2026" for a loan with
    /// a date. Its own tag, since it doesn't fit on one line with the loan text.
    static func dueText(for title: OwnedTitle) -> String? {
        guard title.isLoanedOut, let due = title.loanDueOn else { return nil }
        return "\(title.isLoanOverdue ? "Overdue since" : "Due back") \(due.displayText)"
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

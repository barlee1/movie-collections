//
//  EditTitleViewModel.swift
//  MovieCollection
//
//  Purpose: Draft edits for a title's format, service, where a disc is (and
//  who borrowed it), film rating, tags, and the user's review. Watch history
//  is edited right on the detail screen. Nothing is saved until Save is tapped.
//  Used in: EditTitleSheet.
//

import Foundation
import Observation

@Observable
final class EditTitleViewModel {
    var format: MediaFormat {
        didSet {
            // Drop a service that doesn't fit the new format (e.g. Netflix on a DVD).
            if let service, !format.allowedServices.contains(service) { self.service = nil }
            if format.isPhysical, location == nil { location = appModel.location(.shelf) }
        }
    }
    var service: StreamingService?
    /// Where the disc is. Only used for physical copies.
    var location: StorageLocation?
    var loanedTo: String
    var loanedOn: Date
    var filmRating: FilmRating?
    var tags: [Tag]
    var hasReview: Bool
    var rating: Double
    var reviewText: String

    let title: OwnedTitle
    private let appModel: AppViewModel

    /// - Parameter startWithReview: Turns the review on right away (used by "Write a review").
    init(title: OwnedTitle, appModel: AppViewModel, startWithReview: Bool = false) {
        self.title = title
        self.appModel = appModel
        format = title.format
        service = title.service
        location = title.storageLocation ?? (title.format.isPhysical ? appModel.location(.shelf) : nil)
        loanedTo = title.loanedTo ?? ""
        loanedOn = title.loanedOn ?? .now
        filmRating = title.filmRating
        tags = title.sortedTags
        hasReview = title.review != nil || startWithReview
        rating = title.review?.rating ?? 3
        reviewText = title.review?.text ?? ""
    }

    var locationOptions: [StorageLocation] { appModel.locations }
    var isLoanedOut: Bool { location?.role == .loanedOut }

    /// Digital and Streaming titles need a service before saving.
    var needsService: Bool { format.needsService && service == nil }
    var canSave: Bool { !needsService }

    /// Writes the draft to the title. Returns true when everything saved.
    func save() -> Bool {
        title.filmRating = filmRating
        guard appModel.updateFormat(of: title, format: format, service: service) else { return false }

        if format.isPhysical, let location {
            let borrower = isLoanedOut ? loanedTo : nil
            let changed =
                location !== title.storageLocation
                || (isLoanedOut && (borrower?.trimmed != title.loanedTo || loanedOn != title.loanedOn))
            if changed, !appModel.move(title, to: location, loanedTo: borrower, on: loanedOn) { return false }
        }

        if tags.map(\.id) != title.sortedTags.map(\.id), !appModel.setTags(tags, on: title) { return false }

        if hasReview {
            return appModel.saveReview(for: title, rating: rating, text: reviewText.trimmed)
        } else if title.review != nil {
            return appModel.deleteReview(for: title)
        }
        return true
    }

    /// Removes the title (and its review) from the shelf.
    func removeFromShelf() -> Bool {
        appModel.remove(title)
    }
}

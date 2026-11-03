//
//  TonightViewModel.swift
//  MovieCollection
//
//  Purpose: Tonight's mood filters and the random "Pick one for me".
//  Shared with the detail screen so "Pick another" uses the same filters.
//  Used in: TonightView, TitleDetailView.
//

import Foundation
import Observation
import SwiftData

@Observable
final class TonightViewModel {

    enum RuntimeLimit: String, CaseIterable, Identifiable {
        case any = "Any length"
        case upTo100 = "Up to 1h 40"
        case upTo120 = "Up to 2h"
        case upTo150 = "Up to 2h 30"

        var id: String { rawValue }

        var maxMinutes: Int? {
            switch self {
            case .any: nil
            case .upTo100: 100
            case .upTo120: 120
            case .upTo150: 150
            }
        }
    }

    enum SeenOption: String, CaseIterable, Identifiable {
        case notReviewed = "Not reviewed yet"
        case anything = "Anything"
        case rewatch = "Rewatch"

        var id: String { rawValue }
    }

    /// The user's own star rating, from their review.
    enum StarFilter: String, CaseIterable, Identifiable {
        case any = "Any"
        case threeUp = "3★ and up"
        case fourUp = "4★ and up"
        case fourHalfUp = "4.5★ and up"
        case notRated = "Not rated"

        var id: String { rawValue }

        /// The lowest star rating that fits, for the "and up" options.
        var minimum: Double? {
            switch self {
            case .threeUp: 3
            case .fourUp: 4
            case .fourHalfUp: 4.5
            case .any, .notRated: nil
            }
        }
    }

    var moods: Set<Mood> = []
    var genres: Set<String> = []
    var runtime: RuntimeLimit = .any
    /// nil means any format.
    var format: MediaFormat?
    var seen: SeenOption = .notReviewed {
        didSet { resolveConflict(changed: .seen) }
    }
    var ratings: Set<FilmRating> = []
    /// Something tagged with any of these, e.g. "Date night" (by `Tag.id`).
    var tagIDs: Set<UUID> = []
    var yourRating: StarFilter = .any {
        didSet { resolveConflict(changed: .yourRating) }
    }
    /// Explains a filter that was changed automatically, so the filters never
    /// cancel each other out. Cleared on the next change.
    private(set) var adjustmentNote: String?

    let appModel: AppViewModel

    init(appModel: AppViewModel) {
        self.appModel = appModel
    }

    // MARK: - Options

    /// Genres on the shelf, most common first.
    var genreOptions: [String] {
        let counts = appModel.titles.flatMap(\.genres).reduce(into: [String: Int]()) { $0[$1, default: 0] += 1 }
        return counts.keys.sorted { (counts[$0] ?? 0, $1) > (counts[$1] ?? 0, $0) }
    }

    /// Tags used on at least one title.
    var tagOptions: [Tag] {
        appModel.tags.filter { !$0.titles.isEmpty }
    }

    /// Film ratings that appear on the shelf.
    var ratingOptions: [FilmRating] {
        let used = Set(appModel.titles.compactMap(\.filmRating))
        return FilmRating.allCases.filter(used.contains)
    }

    // MARK: - Matching

    var matches: [OwnedTitle] {
        appModel.titles.filter(fits)
    }

    private func fits(_ title: OwnedTitle) -> Bool {
        if !moods.isEmpty, moods.isDisjoint(with: title.moods) { return false }
        if !genres.isEmpty, genres.isDisjoint(with: title.genres) { return false }
        // Titles without a known runtime aren't ruled out.
        if let max = runtime.maxMinutes, let minutes = title.runtime, minutes > max { return false }
        if let format, title.format != format { return false }
        switch seen {
        case .notReviewed: if title.isReviewed { return false }
        case .rewatch: if !title.isReviewed { return false }
        case .anything: break
        }
        if !ratings.isEmpty {
            guard let rating = title.filmRating, ratings.contains(rating) else { return false }
        }
        if !tagIDs.isEmpty, !title.tags.contains(where: { tagIDs.contains($0.id) }) { return false }
        switch yourRating {
        case .any: break
        case .notRated: if title.isReviewed { return false }
        case .threeUp, .fourUp, .fourHalfUp:
            guard let stars = title.review?.rating, let minimum = yourRating.minimum, stars >= minimum else { return false }
        }
        return true
    }

    // MARK: - Filter conflicts

    private enum ChangedFilter { case seen, yourRating }

    /// A star level needs a review, and "Not rated" rules one out, so a choice
    /// that contradicts "Reviewed it?" moves the other filter to a choice that fits.
    private func resolveConflict(changed: ChangedFilter) {
        adjustmentNote = nil
        let needsReview = yourRating.minimum != nil
        switch changed {
        case .yourRating:
            if needsReview, seen == .notReviewed {
                seen = .anything
                adjustmentNote = "Showing reviewed titles too, since star ratings come from your reviews."
            } else if yourRating == .notRated, seen == .rewatch {
                seen = .anything
                adjustmentNote = "\"Reviewed it?\" changed to Anything, since rewatches are already rated."
            }
        case .seen:
            if seen == .notReviewed, needsReview {
                yourRating = .any
                adjustmentNote = "Your rating changed to Any, since unreviewed titles have no stars yet."
            } else if seen == .rewatch, yourRating == .notRated {
                yourRating = .any
                adjustmentNote = "Your rating changed to Any, since rewatches are already rated."
            }
        }
    }

    /// e.g. "4 on your shelf fit" or "Nothing fits — loosen a filter"
    var matchLabel: String {
        switch matches.count {
        case 0: "Nothing fits — loosen a filter"
        case 1: "1 on your shelf fits"
        case let count: "\(count) on your shelf fit"
        }
    }

    /// A random matching title. Avoids repeating `excluded` when there's another choice.
    func pick(excluding excluded: PersistentIdentifier? = nil) -> PersistentIdentifier? {
        let pool = matches
        let choices = pool.count > 1 ? pool.filter { $0.persistentModelID != excluded } : pool
        return choices.randomElement()?.persistentModelID
    }
}

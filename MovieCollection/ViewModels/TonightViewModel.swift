//
//  TonightViewModel.swift
//  MovieCollection
//
//  Purpose: Tonight's mood filters, "Who's watching?" (family members on
//  the couch, with a film rating suggestion from the youngest one's age),
//  and the random "Pick one for me".
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

    /// The "Seen it?" choices. Rewatch means watched at least once (any logged watch).
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

    /// How unseen a title has to be for the family members watching.
    enum ViewerMode: String, CaseIterable, Identifiable {
        case noneSeen = "None of them have seen it"
        case mostHaventSeen = "Most haven't seen it"

        var id: String { rawValue }
    }

    /// Family members on the couch tonight (by `FamilyMember.id`).
    var viewerIDs: Set<UUID> = [] {
        // A new group gets a fresh age suggestion.
        didSet { usesAgeSuggestion = true }
    }
    /// Whether the user is on the couch too. Only counts while their profile
    /// is listed with the family (see `AppViewModel.familyYou`).
    var includesYou = false {
        didSet { usesAgeSuggestion = true }
    }
    var viewerMode: ViewerMode = .noneSeen
    /// Whether to follow the suggested film ratings for the youngest viewer.
    /// Tapping the suggestion chip turns it off for this group.
    var usesAgeSuggestion = true

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

    // MARK: - Who's watching

    /// The family members picked, in the user's order. Deleted members drop out.
    var viewers: [FamilyMember] {
        appModel.familyMembers.filter { viewerIDs.contains($0.id) }
    }

    /// Whether the user is picked and still listed with the family.
    var isYouWatching: Bool { includesYou && appModel.familyYou != nil }

    /// How many people are picked, counting the user.
    var viewerCount: Int { viewers.count + (isYouWatching ? 1 : 0) }

    /// The youngest viewer with an age, if any.
    var youngestViewer: FamilyMember? {
        viewers.filter { $0.age != nil }.min { ($0.age ?? 0) < ($1.age ?? 0) }
    }

    /// The suggested film ratings for the youngest viewer, if ages are
    /// used and someone is under 17.
    var ageSuggestion: (member: FamilyMember, summary: String, ratings: Set<FilmRating>)? {
        guard appModel.suggestsRatingsFromAges,
            let member = youngestViewer, let age = member.age,
            let summary = FamilyAgeGuide.summary(forAge: age),
            let ratings = FamilyAgeGuide.allowedRatings(forAge: age)
        else { return nil }
        return (member, summary, ratings)
    }

    /// e.g. "G and PG for Sam (8)"
    var ageSuggestionLabel: String? {
        guard let suggestion = ageSuggestion, let age = suggestion.member.age else { return nil }
        return "\(suggestion.summary) for \(suggestion.member.name) (\(age))"
    }

    private func fitsViewers(_ title: OwnedTitle) -> Bool {
        let watching = viewers
        let count = viewerCount
        guard count > 0 else { return true }
        // The user has seen it if they've logged a watch of it.
        let unseen = watching.filter { !title.hasBeenSeen(by: $0) }.count + (isYouWatching && !title.isWatched ? 1 : 0)
        switch viewerMode {
        case .noneSeen: if unseen < count { return false }
        // At least half, so with two watching, one new to it is enough.
        case .mostHaventSeen: if unseen * 2 < count { return false }
        }
        // Titles without a film rating are left out, since their fit is unknown.
        if usesAgeSuggestion, let suggestion = ageSuggestion {
            guard let rating = title.filmRating, suggestion.ratings.contains(rating) else { return false }
        }
        return true
    }

    // MARK: - Matching

    var matches: [OwnedTitle] {
        appModel.titles.filter(fits)
    }

    private func fits(_ title: OwnedTitle) -> Bool {
        if !fitsViewers(title) { return false }
        if !moods.isEmpty, moods.isDisjoint(with: title.moods) { return false }
        if !genres.isEmpty, genres.isDisjoint(with: title.genres) { return false }
        // Titles without a known runtime aren't ruled out.
        if let max = runtime.maxMinutes, let minutes = title.runtime, minutes > max { return false }
        if let format, title.format != format { return false }
        switch seen {
        case .notReviewed: if title.isReviewed { return false }
        case .rewatch: if !title.isWatched { return false }
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

    /// A star level needs a review, so it can't go with "Not reviewed yet"; a
    /// choice that contradicts the other moves it to one that fits. Rewatch
    /// (watched before) works with any rating, including "Not rated".
    private func resolveConflict(changed: ChangedFilter) {
        adjustmentNote = nil
        guard seen == .notReviewed, yourRating.minimum != nil else { return }
        switch changed {
        case .yourRating:
            seen = .anything
            adjustmentNote = "Showing reviewed titles too, since star ratings come from your reviews."
        case .seen:
            yourRating = .any
            adjustmentNote = "Your rating changed to Any, since unreviewed titles have no stars yet."
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

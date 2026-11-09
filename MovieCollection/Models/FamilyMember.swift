//
//  FamilyMember.swift
//  MovieCollection
//
//  Purpose: The people the user watches with, like "Sam, 8". Each has a
//  name, an optional age, and an avatar color. A watch can record which
//  members were there, and a `FamilyRating` holds one member's own stars
//  for a title (or just that they've seen it, without a logged watch).
//  Family data stays on this phone only and is never shared.
//  Used in: CollectionStore, Settings › Family, the detail screen, the
//  watch sheet, the Shelf's "Not seen by" filter, and Tonight's "Who's watching?".
//  Part of SchemaV4 (see SchemaVersions.swift); the app uses the FamilyMember
//  and FamilyRating typealiases.
//

import Foundation
import SwiftData

extension SchemaV4 {
    @Model
    final class FamilyMember {
        var id: UUID
        var name: String
        /// Age in years, if the user entered one. Used to suggest film ratings on Tonight.
        var age: Int?
        /// Which theme color the avatar circle uses; see `TagPalette`.
        var colorIndex: Int
        /// Position in lists, lowest first.
        var sortOrder: Int

        /// Their ratings and "seen it" marks. Deleting a member deletes these.
        @Relationship(deleteRule: .cascade, inverse: \FamilyRating.member)
        var ratings: [FamilyRating] = []

        /// Watches they were at. Deleting a member just takes them off these.
        @Relationship(deleteRule: .nullify, inverse: \WatchEvent.viewers)
        var watches: [WatchEvent] = []

        init(name: String, age: Int? = nil, colorIndex: Int = 0, sortOrder: Int = 0) {
            self.id = UUID()
            self.name = name
            self.age = age
            self.colorIndex = colorIndex
            self.sortOrder = sortOrder
        }

        /// The most family members a shelf can have.
        static let limit = 15
    }

    /// One family member's take on one title: their own half-star rating,
    /// and whether they've seen it even with no logged watch (say, at a
    /// friend's house). A member has seen a title if this says so, or if
    /// they were at one of its watches.
    @Model
    final class FamilyRating {
        /// Stars from 0.5 to 5 in half-star steps, or nil if they haven't rated it.
        var rating: Double?
        /// Checked "seen" on the detail screen, apart from any logged watch.
        var markedSeen: Bool
        var member: FamilyMember?
        var ownedTitle: OwnedTitle?

        init(rating: Double? = nil, markedSeen: Bool = true) {
            self.rating = rating.map(Review.normalized)
            self.markedSeen = markedSeen
        }
    }
}

// MARK: - Who has seen what

extension SchemaV4.OwnedTitle {
    /// The member's rating and "seen" mark for this title, if there is one.
    func familyRecord(for member: FamilyMember) -> FamilyRating? {
        familyRatings.first { $0.member?.id == member.id }
    }

    /// Watches the member was at.
    func watches(seenBy member: FamilyMember) -> [WatchEvent] {
        watches.filter { watch in watch.viewers.contains { $0.id == member.id } }
    }

    /// Their most recent logged watch, or nil if none is logged.
    func lastWatched(by member: FamilyMember) -> Date? {
        watches(seenBy: member).map(\.date).max()
    }

    /// Whether they were at a watch, checked it as seen, or rated it.
    func hasBeenSeen(by member: FamilyMember) -> Bool {
        if let record = familyRecord(for: member), record.markedSeen || record.rating != nil { return true }
        return watches.contains { watch in watch.viewers.contains { $0.id == member.id } }
    }

    func familyRating(for member: FamilyMember) -> Double? {
        familyRecord(for: member)?.rating
    }
}

extension SchemaV4.FamilyMember {
    /// "S" for Sam: the letter in their avatar circle.
    var initial: String { name.trimmed.first.map { String($0).uppercased() } ?? "?" }

    /// e.g. "Sam, 8" or "Sam"
    var nameWithAge: String { age.map { "\(name), \($0)" } ?? name }
}

// MARK: - Age-based film rating suggestions

/// Suggests which film ratings fit the youngest person watching.
nonisolated enum FamilyAgeGuide {
    /// The oldest age that still gets a suggestion. 17 and up can watch anything.
    static let adultAge = 17

    /// Ratings that fit someone this age, or nil if anything goes.
    static func allowedRatings(forAge age: Int) -> Set<FilmRating>? {
        switch age {
        case ..<13: [.g, .pg, .tvY, .tvG, .tvPG]
        case ..<adultAge: [.g, .pg, .pg13, .tvY, .tvG, .tvPG, .tv14]
        default: nil
        }
    }

    /// Short chip text for the suggestion, e.g. "G and PG" or "Up to PG-13".
    static func summary(forAge age: Int) -> String? {
        switch age {
        case ..<13: "G and PG"
        case ..<adultAge: "Up to PG-13"
        default: nil
        }
    }
}

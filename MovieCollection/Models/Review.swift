//
//  Review.swift
//  MovieCollection
//
//  Purpose: The user's own review of a title: a half-star rating, text, and date.
//  Used in: OwnedTitle, CollectionStore, Reviews tab, edit sheet.
//  Part of SchemaV2 (see SchemaVersions.swift); the app uses the Review typealias.
//

import Foundation
import SwiftData

extension SchemaV2 {
    @Model
    final class Review {
        /// Stars from 0.5 to 5 in half-star steps.
        var rating: Double
        var text: String
        var date: Date
        var ownedTitle: OwnedTitle?

        init(rating: Double, text: String, date: Date = .now) {
            self.rating = Review.normalized(rating)
            self.text = text
            self.date = date
        }

        static let minimumRating = 0.5
        static let maximumRating = 5.0

        /// Rounds to the nearest half star and keeps it within 0.5...5.
        nonisolated static func normalized(_ rating: Double) -> Double {
            let halfSteps = (rating * 2).rounded() / 2
            return min(max(halfSteps, minimumRating), maximumRating)
        }
    }
}

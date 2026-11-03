//
//  FriendReview.swift
//  MovieCollection
//
//  Purpose: A review from one of the user's friends. There's no backend yet,
//  so these are fixed sample reviews from the design.
//  Used in: Friends screen.
//

import Foundation

nonisolated struct FriendReview: Identifiable, Hashable, Sendable {
    let id = UUID()
    let friendName: String
    let date: Date
    let title: String
    /// Stars from 0.5 to 5 in half-star steps.
    let rating: Double
    let text: String

    /// Initials for the avatar circle, e.g. "TJ" for Tatum Johnson.
    var initials: String {
        friendName
            .split(separator: " ")
            .compactMap(\.first)
            .map(String.init)
            .joined()
    }

    static let samples: [FriendReview] = [
        FriendReview(
            friendName: "Tatum Johnson",
            date: .calendarDate(2025, 8, 27),
            title: "The Lego Batman Movie",
            rating: 5,
            text: "You can not make a better movie than this! It was laugh out loud funny. Will be watching again"
        ),
        FriendReview(
            friendName: "Remi Nichol",
            date: .calendarDate(2025, 8, 26),
            title: "Avengers Infinity War",
            rating: 3,
            text: "Loved everything except the end…"
        ),
        FriendReview(
            friendName: "Gracie Brown",
            date: .calendarDate(2025, 8, 20),
            title: "Holes",
            rating: 4,
            text: "Loved this movie when I was younger, it was just as good this time around!"
        ),
    ]
}

extension Date {
    /// A midday date in the current calendar, for fixed sample data.
    /// Midday keeps the day stable across time zones.
    nonisolated static func calendarDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
        let components = DateComponents(year: year, month: month, day: day, hour: 12)
        return Calendar.current.date(from: components) ?? .now
    }
}

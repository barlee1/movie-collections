//
//  WatchEvent.swift
//  MovieCollection
//
//  Purpose: One time a title was watched: its date and an optional note.
//  A title's watches make up its watch history ("1st watch", "2nd watch").
//  Later, a watch can also record which family members were there.
//  Used in: OwnedTitle, CollectionStore, the detail screen's watch history.
//  Part of SchemaV2 (see SchemaVersions.swift); the app uses the WatchEvent typealias.
//

import Foundation
import SwiftData

extension SchemaV2 {
    @Model
    final class WatchEvent {
        var date: Date
        var note: String
        var ownedTitle: OwnedTitle?

        init(date: Date, note: String = "") {
            self.date = date
            self.note = note
        }
    }
}

/// Labels for a title's watch history.
nonisolated enum WatchHistoryText {
    /// "1st", "2nd", "3rd", "4th", "11th", "12th", "13th", "21st", "22nd", and so on.
    static func ordinal(_ number: Int) -> String {
        let lastTwo = number % 100
        let suffix =
            if (11...13).contains(lastTwo) {
                "th"
            } else {
                switch number % 10 {
                case 1: "st"
                case 2: "nd"
                case 3: "rd"
                default: "th"
                }
            }
        return "\(number)\(suffix)"
    }

    /// e.g. "Watched once" or "Watched 3 times"
    static func count(_ watches: Int) -> String {
        switch watches {
        case 0: "Not watched yet"
        case 1: "Watched once"
        case 2: "Watched twice"
        default: "Watched \(watches) times"
        }
    }
}

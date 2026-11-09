//
//  OwnedTitle.swift
//  MovieCollection
//
//  Purpose: A movie or TV show on the shelf, saved on device with SwiftData.
//  Catalog details are copied in when added, so every field stays editable
//  and hand-entered titles work the same way as catalog ones. Holds the
//  title's watch history, where a disc physically is, and its tags.
//  Used in: CollectionStore, shelf, detail, edit sheet, Tonight, profile.
//  Part of SchemaV4 (see SchemaVersions.swift); the app uses the OwnedTitle typealias.
//

import Foundation
import SwiftData

extension SchemaV4 {
    @Model
    final class OwnedTitle {
        /// The catalog Movie this came from, or nil if entered by hand.
        var catalogID: Int?
        var title: String
        var kind: TitleKind
        var genres: [String]
        var overview: String
        var year: Int?
        /// Runtime in minutes (per episode for TV shows).
        var runtime: Int?
        /// Director for movies, creators for TV shows.
        var director: String
        var cast: [String]
        var filmRating: FilmRating?
        var imdbID: String?

        var format: MediaFormat
        /// Where a Digital or Streaming title lives. Always nil for DVDs.
        var service: StreamingService?
        var dateAdded: Date

        /// A single watched date waiting to become a watch event: version 1's
        /// `lastWatched`, or the date passed to `init`. CollectionStore turns it
        /// into the first `WatchEvent` when the title is saved, then clears it.
        @Attribute(originalName: "lastWatched")
        var legacyLastWatched: Date?

        /// The user's review. Deleting the title deletes its review too.
        @Relationship(deleteRule: .cascade, inverse: \Review.ownedTitle)
        var review: Review?

        /// Every time it's been watched. Deleting the title deletes its watches.
        @Relationship(deleteRule: .cascade, inverse: \WatchEvent.ownedTitle)
        var watches: [WatchEvent] = []

        /// Where a DVD physically is, e.g. Shelf or Loaned out. Nil for digital and streaming.
        var storageLocation: StorageLocation?
        /// Who borrowed it, while it's Loaned out.
        var loanedTo: String?
        var loanedOn: Date?
        /// Where it goes back to when it's returned.
        var locationBeforeLoanID: UUID?
        /// When the borrower said they'd bring it back, if a date was set.
        /// A notification reminds the user that morning (see LoanReminders).
        var loanDueOn: Date?

        var tags: [Tag] = []

        /// Family members' ratings and "seen" marks. Deleting the title deletes these.
        @Relationship(deleteRule: .cascade, inverse: \FamilyRating.ownedTitle)
        var familyRatings: [FamilyRating] = []

        init(
            catalogID: Int? = nil,
            title: String,
            kind: TitleKind = .movie,
            genres: [String] = [],
            overview: String = "",
            year: Int? = nil,
            runtime: Int? = nil,
            director: String = "",
            cast: [String] = [],
            filmRating: FilmRating? = nil,
            imdbID: String? = nil,
            format: MediaFormat,
            service: StreamingService? = nil,
            lastWatched: Date? = nil,
            dateAdded: Date = .now
        ) {
            self.catalogID = catalogID
            self.title = title
            self.kind = kind
            self.genres = genres
            self.overview = overview
            self.year = year
            self.runtime = runtime
            self.director = director
            self.cast = cast
            self.filmRating = filmRating
            self.imdbID = imdbID
            self.format = format
            // DVDs never have a service, whatever was passed in.
            self.service = format.needsService ? service : nil
            // Becomes the first watch event once saved (see CollectionStore.add).
            self.legacyLastWatched = lastWatched
            self.dateAdded = dateAdded
        }

        /// Creates a shelf entry by copying a catalog movie's details.
        convenience init(
            movie: Movie,
            format: MediaFormat,
            service: StreamingService? = nil,
            lastWatched: Date? = nil,
            dateAdded: Date = .now
        ) {
            self.init(
                catalogID: movie.id,
                title: movie.title,
                kind: .movie,
                genres: movie.genres,
                overview: movie.overview,
                year: movie.year,
                runtime: movie.runtime,
                director: movie.director,
                cast: movie.cast,
                filmRating: movie.filmRating,
                imdbID: movie.imdbID,
                format: format,
                service: service,
                lastWatched: lastWatched,
                dateAdded: dateAdded
            )
        }

        // MARK: - Derived values

        var isReviewed: Bool { review != nil }
        var moods: [Mood] { Mood.moods(forGenres: genres) }
        var posterLetter: String { TitleDisplay.posterLetter(for: title) }
        var imdbURL: URL? { TitleDisplay.imdbURL(imdbID: imdbID, title: title) }
        var trailerURL: URL? { TitleDisplay.trailerURL(title: title, year: year) }

        // MARK: Watch history

        /// Watches, newest first.
        var sortedWatches: [WatchEvent] { watches.sorted { $0.date > $1.date } }

        /// The most recent watch, or nil if it's never been watched.
        var lastWatched: Date? { watches.map(\.date).max() ?? legacyLastWatched }

        var watchCount: Int { max(watches.count, legacyLastWatched == nil ? 0 : 1) }
        var isWatched: Bool { watchCount > 0 }

        // MARK: Location

        var isLoanedOut: Bool { storageLocation?.role == .loanedOut }

        /// Loaned out and past its due-back day.
        var isLoanOverdue: Bool {
            guard isLoanedOut, let loanDueOn else { return false }
            return Calendar.current.startOfDay(for: loanDueOn) < Calendar.current.startOfDay(for: .now)
        }

        // MARK: Tags

        /// Tags in A to Z order.
        var sortedTags: [Tag] { tags.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending } }
    }
}

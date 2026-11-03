//
//  ShelfSeeder.swift
//  MovieCollection
//
//  Purpose: The optional sample shelf: 30 catalog movies (and the design's two
//  sample reviews). Never added automatically: signed-in users can load or
//  remove it from Profile › About, and previews and UI tests use it.
//  Used in: AppViewModel.
//

import Foundation

nonisolated enum ShelfSeeder {

    /// One sample shelf entry, matched to the catalog by TMDB ID.
    struct Entry {
        let catalogID: Int
        let format: MediaFormat
        var service: StreamingService? = nil
        var lastWatched: Date? = nil
        var review: (rating: Double, text: String, date: Date)? = nil
    }

    /// Adds the sample titles that aren't already on the shelf.
    /// Returns the number of titles added.
    @MainActor
    @discardableResult
    static func addSampleShelf(to store: CollectionStore, catalog: [Movie]) throws -> Int {
        let moviesByID = Dictionary(uniqueKeysWithValues: catalog.map { ($0.id, $0) })
        var added = 0

        // Stagger "date added" so the newest-first order is stable.
        for (offset, entry) in entries.enumerated() {
            guard let movie = moviesByID[entry.catalogID], try !store.contains(catalogID: entry.catalogID) else { continue }
            let title = OwnedTitle(
                movie: movie,
                format: entry.format,
                service: entry.service,
                lastWatched: entry.lastWatched,
                dateAdded: Date.now.addingTimeInterval(-Double(offset) * 60)
            )
            try store.add(title)
            if let review = entry.review {
                try store.saveReview(for: title, rating: review.rating, text: review.text, date: review.date)
            }
            added += 1
        }
        return added
    }

    /// Removes the sample titles (and their reviews), leaving anything the
    /// user added themselves. Returns the number removed.
    @MainActor
    @discardableResult
    static func removeSampleShelf(from store: CollectionStore) throws -> Int {
        let sampleIDs = Set(entries.map(\.catalogID))
        let samples = try store.allTitles().filter { $0.catalogID.map(sampleIDs.contains) ?? false }
        for title in samples {
            try store.delete(title)
        }
        return samples.count
    }

    /// Whether any sample title is on the shelf.
    @MainActor
    static func hasSampleTitles(in titles: [OwnedTitle]) -> Bool {
        let sampleIDs = Set(entries.map(\.catalogID))
        return titles.contains { $0.catalogID.map(sampleIDs.contains) ?? false }
    }

    /// Whether every sample title is already on the shelf.
    @MainActor
    static func isSampleShelfLoaded(in titles: [OwnedTitle]) -> Bool {
        let onShelf = Set(titles.compactMap(\.catalogID))
        return entries.allSatisfy { onShelf.contains($0.catalogID) }
    }

    // MARK: - Starting shelf

    /// The 30 sample titles: a mix of formats, services, and ratings
    /// (including plenty of G and PG picks for watching with kids).
    static let entries: [Entry] = [
        // From the design
        Entry(
            catalogID: 1893, format: .dvd, lastWatched: .calendarDate(2024, 9, 25),  // The Phantom Menace
            review: (
                2,
                "Feels like George Lucas handed me a bag of toys and said \"imagine the rest yourself.\" There's a weird charm to that, but also a lot of boredom.",
                .calendarDate(2024, 9, 25)
            )
        ),
        Entry(
            catalogID: 2044, format: .dvd, lastWatched: .calendarDate(2017, 9, 23),  // The Lake House
            review: (
                4,
                "Communicating through a magic mailbox is the exact brand of nonsense I'm a sucker for. It's slow, it's melancholic, and it absolutely does not care if the time travel mechanics make sense (they don't).",
                .calendarDate(2017, 9, 23)
            )
        ),
        Entry(catalogID: 38055, format: .digital, service: .amazonPrime, lastWatched: .calendarDate(2023, 3, 2)),  // Megamind
        Entry(catalogID: 272, format: .digital, service: .plex, lastWatched: .calendarDate(2022, 7, 14)),  // Batman Begins
        Entry(catalogID: 568, format: .dvd),  // Apollo 13
        Entry(catalogID: 297762, format: .streaming, service: .amazonPrime, lastWatched: .calendarDate(2020, 12, 26)),  // Wonder Woman

        // Family and animated
        Entry(catalogID: 862, format: .dvd, lastWatched: .calendarDate(2025, 11, 29)),  // Toy Story
        Entry(catalogID: 12, format: .dvd),  // Finding Nemo
        Entry(catalogID: 109445, format: .digital, service: .plex, lastWatched: .calendarDate(2025, 12, 24)),  // Frozen
        Entry(catalogID: 150540, format: .streaming, service: .netflix),  // Inside Out
        Entry(catalogID: 14160, format: .dvd),  // Up
        Entry(catalogID: 269149, format: .streaming, service: .netflix, lastWatched: .calendarDate(2026, 2, 14)),  // Zootopia
        Entry(catalogID: 10191, format: .digital, service: .amazonPrime),  // How to Train Your Dragon
        Entry(catalogID: 671, format: .dvd, lastWatched: .calendarDate(2025, 10, 31)),  // Harry Potter and the Philosopher's Stone
        Entry(catalogID: 673, format: .dvd),  // Harry Potter and the Prisoner of Azkaban

        // Adventure and classics
        Entry(catalogID: 120, format: .dvd),  // The Fellowship of the Ring
        Entry(catalogID: 11, format: .dvd, lastWatched: .calendarDate(2025, 5, 4)),  // Star Wars
        Entry(catalogID: 105, format: .digital, service: .plex),  // Back to the Future
        Entry(catalogID: 329, format: .dvd),  // Jurassic Park
        Entry(catalogID: 85, format: .dvd),  // Raiders of the Lost Ark
        Entry(catalogID: 597, format: .dvd),  // Titanic
        Entry(catalogID: 13, format: .streaming, service: .amazonPrime),  // Forrest Gump

        // Grown-up picks
        Entry(catalogID: 27205, format: .digital, service: .plex, lastWatched: .calendarDate(2024, 1, 12)),  // Inception
        Entry(catalogID: 157336, format: .streaming, service: .netflix),  // Interstellar
        Entry(catalogID: 286217, format: .streaming, service: .amazonPrime),  // The Martian
        Entry(catalogID: 313369, format: .streaming, service: .netflix),  // La La Land
        Entry(catalogID: 120467, format: .digital, service: .amazonPrime),  // The Grand Budapest Hotel
        Entry(catalogID: 278, format: .streaming, service: .netflix),  // The Shawshank Redemption
        Entry(catalogID: 603, format: .digital, service: .plex),  // The Matrix
        Entry(catalogID: 640, format: .streaming, service: .amazonPrime),  // Catch Me If You Can
    ]
}

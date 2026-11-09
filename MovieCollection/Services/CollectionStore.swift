//
//  CollectionStore.swift
//  MovieCollection
//
//  Purpose: The one place that reads and writes the user's shelf and reviews
//  in SwiftData, so ViewModels never touch the model context directly.
//  Used in: AppViewModel, ShelfSeeder, and the screen ViewModels.
//

import Foundation
import SwiftData

final class CollectionStore {
    /// Held so the container (and its store) lives as long as this object.
    let container: ModelContainer
    let context: ModelContext

    init(container: ModelContainer) {
        self.container = container
        self.context = container.mainContext
    }

    /// The versioned container every part of the app uses, so saved shelves
    /// upgrade through `RewindClubMigrationPlan` when the models change.
    /// - Parameter inMemory: True for previews and tests, which need a throwaway store.
    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        try ModelContainer(
            for: Schema(versionedSchema: SchemaV4.self),
            migrationPlan: RewindClubMigrationPlan.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: inMemory)
        )
    }

    // MARK: - Reading

    /// Every title on the shelf, sorted by title.
    func allTitles() throws -> [OwnedTitle] {
        let descriptor = FetchDescriptor<OwnedTitle>(sortBy: [SortDescriptor(\.title)])
        return try context.fetch(descriptor)
    }

    /// Every review, newest first.
    func allReviews() throws -> [Review] {
        let descriptor = FetchDescriptor<Review>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        return try context.fetch(descriptor)
    }

    /// Looks up a shelf title by its persistent ID (used by navigation routes).
    func title(with id: PersistentIdentifier) -> OwnedTitle? {
        context.model(for: id) as? OwnedTitle
    }

    /// Whether a catalog movie is already on the shelf.
    func contains(catalogID: Int) throws -> Bool {
        let descriptor = FetchDescriptor<OwnedTitle>(predicate: #Predicate { $0.catalogID == catalogID })
        return try context.fetchCount(descriptor) > 0
    }

    // MARK: - Writing

    /// Adds a title to the shelf and saves. A watched date given to the
    /// title becomes its first watch, and a new DVD goes on the Shelf.
    func add(_ title: OwnedTitle) throws {
        context.insert(title)
        try settleLegacyFields(of: title)
        try context.save()
    }

    /// Removes a title (and its review) from the shelf and saves.
    func delete(_ title: OwnedTitle) throws {
        context.delete(title)
        try context.save()
    }

    /// Updates how the user has a title. Clears the service for DVDs, and
    /// gives a disc a place (or clears it for digital and streaming).
    func updateFormat(of title: OwnedTitle, format: MediaFormat, service: StreamingService?) throws {
        title.format = format
        title.service = format.needsService ? service : nil
        try settleLocation(of: title)
        try context.save()
    }

    /// Creates or replaces the user's review of a title.
    @discardableResult
    func saveReview(for title: OwnedTitle, rating: Double, text: String, date: Date = .now) throws -> Review {
        if let review = title.review {
            review.rating = Review.normalized(rating)
            review.text = text
            review.date = date
            try context.save()
            return review
        }
        let review = Review(rating: rating, text: text, date: date)
        context.insert(review)
        title.review = review
        try context.save()
        return review
    }

    /// Removes the user's review of a title.
    func deleteReview(for title: OwnedTitle) throws {
        guard let review = title.review else { return }
        title.review = nil
        context.delete(review)
        try context.save()
    }

    /// Saves any edits made directly to a title's properties.
    func save() throws {
        try context.save()
    }
}

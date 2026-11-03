//
//  FormTests.swift
//  MovieCollectionTests
//
//  Purpose: The "Type it in" add form (catalog autofill, hand entry,
//  validation) and the edit sheet (location, rating, watched, review).
//

import Foundation
import SwiftData
import Testing

@testable import MovieCollection

@Suite("Add form")
@MainActor
struct AddTitleViewModelTests {

    @Test("Typing suggests catalog movies; picking one fills every field")
    func autofill() async throws {
        let form = AddTitleViewModel(appModel: try await TestSupport.makeAppModel())
        form.title = "s"
        #expect(form.suggestions.isEmpty, "One letter is too short to search")

        form.title = "shrek"
        let shrek = try #require(form.suggestions.first { $0.title == "Shrek" })
        form.pick(shrek)

        #expect(form.title == "Shrek")
        #expect(form.yearText == "2001")
        #expect(form.runtimeText == "90")
        #expect(form.director == "Andrew Adamson, Vicky Jenson")
        #expect(form.castText.contains("Mike Myers"))
        #expect(form.filmRating == .pg)
        #expect(form.suggestions.isEmpty, "Suggestions hide once a movie is picked")
    }

    @Test("Saving a picked movie links it to the catalog and opens its ID")
    func savesCatalogMovie() async throws {
        let appModel = try await TestSupport.makeAppModel(seeded: false)
        let form = AddTitleViewModel(appModel: appModel)
        form.title = "shrek"
        form.pick(try #require(form.suggestions.first { $0.title == "Shrek" }))
        form.format = .streaming
        #expect(!form.canSave, "Streaming needs a service")
        form.service = .netflix

        let id = try #require(form.save())
        let saved = try #require(appModel.title(with: id))
        #expect(saved.catalogID == 808)
        #expect(saved.imdbID != nil)
        #expect(saved.service == .netflix)
        #expect(saved.cast.count == 3)
        #expect(appModel.isOnShelf(catalogID: 808))
    }

    @Test("Editing the title after picking turns it into a hand-entered title")
    func editingUnlinks() async throws {
        let appModel = try await TestSupport.makeAppModel(seeded: false)
        let form = AddTitleViewModel(appModel: appModel)
        form.title = "shrek"
        form.pick(try #require(form.suggestions.first { $0.title == "Shrek" }))
        form.title = "Shrek (Director's Cut)"

        let saved = try #require(form.save().flatMap(appModel.title(with:)))
        #expect(saved.catalogID == nil)
        #expect(saved.imdbID == nil)
        #expect(saved.year == 2001, "The other picked details are kept")
    }

    @Test("Hand-entered TV shows save with typed lists and a watched date")
    func handEntry() async throws {
        let appModel = try await TestSupport.makeAppModel(seeded: false)
        let form = AddTitleViewModel(appModel: appModel)
        form.title = "  Corner Gas  "
        form.kind = .tvShow
        form.yearText = "2004"
        form.runtimeText = "22"
        form.castText = "Brent Butt, , Gabrielle Miller "
        form.genresText = "Comedy"
        form.filmRating = .tvPG
        form.hasWatched = true

        let saved = try #require(form.save().flatMap(appModel.title(with:)))
        #expect(saved.title == "Corner Gas")
        #expect(saved.kind == .tvShow)
        #expect(saved.cast == ["Brent Butt", "Gabrielle Miller"])
        #expect(saved.moods == [.laughOutLoud])
        #expect(saved.lastWatched != nil)
        #expect(appModel.tvShowCount == 1)
    }

    @Test(
        "Validation blocks saving until the form is complete",
        arguments: [
            ("", "", "", false),  // no title
            ("Up", "", "", true),  // title only is enough
            ("Up", "20O9", "", false),  // year isn't a number
            ("Up", "1800", "", false),  // year too early
            ("Up", "2009", "0", false),  // runtime must be positive
            ("Up", "2009", "96", true),
        ])
    func validation(title: String, year: String, runtime: String, canSave: Bool) async throws {
        let form = AddTitleViewModel(appModel: try await TestSupport.makeAppModel(seeded: false))
        form.title = title
        form.yearText = year
        form.runtimeText = runtime
        #expect(form.canSave == canSave)
    }

    @Test("Switching kind or format clears choices that no longer apply")
    func clearsIncompatibleChoices() async throws {
        let form = AddTitleViewModel(appModel: try await TestSupport.makeAppModel(seeded: false))
        form.filmRating = .pg13
        form.kind = .tvShow
        #expect(form.filmRating == nil)

        form.format = .streaming
        form.service = .netflix
        form.format = .digital
        #expect(form.service == nil, "Netflix doesn't sell digital copies")
    }

    @Test("Warns when the picked movie is already on the shelf")
    func duplicateWarning() async throws {
        let form = AddTitleViewModel(appModel: try await TestSupport.makeAppModel())
        form.title = "megamind"
        form.pick(try #require(form.suggestions.first { $0.title == "Megamind" }))
        #expect(form.isAlreadyOnShelf)
    }
}

@Suite("Edit sheet")
@MainActor
struct EditTitleViewModelTests {

    @Test("Saves location, rating, and watched date")
    func savesDetails() async throws {
        let appModel = try await TestSupport.makeAppModel()
        let apollo = try #require(appModel.titles.first { $0.title == "Apollo 13" })
        let edit = EditTitleViewModel(title: apollo, appModel: appModel)
        #expect(!edit.hasWatched)

        edit.format = .streaming
        #expect(!edit.canSave)
        edit.service = .netflix
        edit.filmRating = .pg13
        edit.hasWatched = true
        #expect(edit.save())

        #expect(apollo.format == .streaming)
        #expect(apollo.service == .netflix)
        #expect(apollo.filmRating == .pg13)
        #expect(apollo.lastWatched != nil)
    }

    @Test("Creates, updates, and deletes Ella's review")
    func reviewLifecycle() async throws {
        let appModel = try await TestSupport.makeAppModel()
        let apollo = try #require(appModel.titles.first { $0.title == "Apollo 13" })

        let writing = EditTitleViewModel(title: apollo, appModel: appModel, startWithReview: true)
        #expect(writing.hasReview, "Write a review starts with the review on")
        writing.rating = 4.5
        writing.reviewText = "  Houston, we have a classic.  "
        #expect(writing.save())
        #expect(apollo.review?.rating == 4.5)
        #expect(apollo.review?.text == "Houston, we have a classic.")

        let updating = EditTitleViewModel(title: apollo, appModel: appModel)
        #expect(updating.rating == 4.5)
        updating.rating = 3
        #expect(updating.save())
        #expect(apollo.review?.rating == 3)

        let deleting = EditTitleViewModel(title: apollo, appModel: appModel)
        deleting.hasReview = false
        #expect(deleting.save())
        #expect(apollo.review == nil)
        #expect(try appModel.store.allReviews().count == 2, "Only the two seeded reviews remain")
    }

    @Test("Cancelling leaves the title unchanged")
    func cancelling() async throws {
        let appModel = try await TestSupport.makeAppModel()
        let apollo = try #require(appModel.titles.first { $0.title == "Apollo 13" })
        let edit = EditTitleViewModel(title: apollo, appModel: appModel)
        edit.format = .digital
        edit.service = .plex
        // No save() call, as when Cancel is tapped.
        #expect(apollo.format == .dvd)
        #expect(apollo.service == nil)
    }

    @Test("Removing from the shelf deletes the title")
    func removes() async throws {
        let appModel = try await TestSupport.makeAppModel()
        let lakeHouse = try #require(appModel.titles.first { $0.title == "The Lake House" })
        #expect(EditTitleViewModel(title: lakeHouse, appModel: appModel).removeFromShelf())
        #expect(appModel.titles.count == 29)
        #expect(appModel.reviewedTitles.count == 1)
    }
}

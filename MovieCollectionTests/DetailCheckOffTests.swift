//
//  DetailCheckOffTests.swift
//  MovieCollectionTests
//
//  Purpose: The Watched and Reviewed check-offs on the detail screen, which
//  save immediately without opening the Edit sheet.
//

import Foundation
import SwiftData
import Testing

@testable import MovieCollection

@Suite("Detail check-offs")
@MainActor
struct DetailCheckOffTests {

    private func makeDetail(for titleName: String) async throws -> (TitleDetailViewModel, OwnedTitle) {
        let appModel = try await TestSupport.makeAppModel()
        let title = try #require(appModel.titles.first { $0.title == titleName })
        let detail = TitleDetailViewModel(titleID: title.persistentModelID, fromTonight: false, appModel: appModel)
        return (detail, title)
    }

    @Test("Checking Watched sets today's date; unchecking clears it")
    func watched() async throws {
        let (detail, apollo) = try await makeDetail(for: "Apollo 13")
        #expect(!detail.isWatched)
        #expect(detail.watchedLabel == "Not watched yet")

        detail.setWatched(true)
        #expect(detail.isWatched)
        #expect(Calendar.current.isDateInToday(try #require(apollo.lastWatched)))

        detail.setWatched(false)
        #expect(!detail.isWatched)
        #expect(apollo.lastWatched == nil)
    }

    @Test("Checking Watched again keeps the original date")
    func watchedIsIdempotent() async throws {
        let (detail, toyStory) = try await makeDetail(for: "Toy Story")
        let original = try #require(toyStory.lastWatched)
        detail.setWatched(true)
        #expect(toyStory.lastWatched == original)
    }

    @Test("Checking Reviewed creates a review to rate; the stars update it")
    func reviewed() async throws {
        let (detail, apollo) = try await makeDetail(for: "Apollo 13")
        #expect(!detail.isReviewed)

        detail.setReviewed(true)
        #expect(detail.isReviewed)
        #expect(detail.rating == TitleDetailViewModel.quickReviewRating)
        #expect(detail.appModel.reviewedTitles.contains { $0.title == "Apollo 13" })

        detail.setRating(4.5)
        #expect(apollo.review?.rating == 4.5)
    }

    @Test("Unchecking a review with no text removes it right away")
    func uncheckEmptyReview() async throws {
        let (detail, apollo) = try await makeDetail(for: "Apollo 13")
        detail.setReviewed(true)
        detail.setReviewed(false)
        #expect(!detail.isConfirmingReviewRemoval)
        #expect(apollo.review == nil)
    }

    @Test("Unchecking a written review asks first, and only removes it once confirmed")
    func uncheckWrittenReview() async throws {
        let (detail, lakeHouse) = try await makeDetail(for: "The Lake House")
        #expect(detail.isReviewed)

        detail.setReviewed(false)
        #expect(detail.isConfirmingReviewRemoval)
        #expect(lakeHouse.review != nil, "Nothing is deleted until confirmed")

        detail.confirmReviewRemoval()
        #expect(lakeHouse.review == nil)
        #expect(!detail.isReviewed)
    }

    @Test("The note sheet saves the rating and note together")
    func saveNote() async throws {
        let (detail, apollo) = try await makeDetail(for: "Apollo 13")
        detail.setReviewed(true)
        detail.saveNote(rating: 4.5, note: "Houston, we have a classic.")
        #expect(apollo.review?.rating == 4.5)
        #expect(apollo.review?.text == "Houston, we have a classic.")
        #expect(detail.reviewNote == "Houston, we have a classic.")
    }

    @Test("Changing the stars keeps the written text")
    func ratingKeepsText() async throws {
        let (detail, lakeHouse) = try await makeDetail(for: "The Lake House")
        let text = try #require(lakeHouse.review?.text)
        detail.setRating(2.5)
        #expect(lakeHouse.review?.rating == 2.5)
        #expect(lakeHouse.review?.text == text)
    }
}

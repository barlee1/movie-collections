//
//  ModelTests.swift
//  MovieCollectionTests
//
//  Purpose: Rules built into the models: half-star rounding, moods from
//  genres, placeholder letters, IMDb links, ratings, formats, and services.
//

import Foundation
import SwiftData
import Testing

@testable import MovieCollection

@Suite("Models")
struct ModelTests {

    @Test(
        "Ratings round to the nearest half star within 0.5–5",
        arguments: [
            (0.0, 0.5), (0.3, 0.5), (1.0, 1.0), (2.26, 2.5), (3.74, 3.5), (4.75, 5.0), (9.0, 5.0), (-2.0, 0.5),
        ])
    func halfStarRounding(input: Double, expected: Double) {
        #expect(Review.normalized(input) == expected)
    }

    @Test("Moods come from genres, in Tonight's order, without duplicates")
    func moods() {
        #expect(Mood.moods(forGenres: ["Comedy"]) == [.laughOutLoud])
        #expect(Mood.moods(forGenres: ["Animation", "Family"]) == [.feelGood, .laughOutLoud])
        #expect(Mood.moods(forGenres: ["Romance", "Mystery"]) == [.edgeOfSeat, .cozy])
        #expect(Mood.moods(forGenres: ["Documentary"]).isEmpty)
        #expect(Mood.moods(forGenres: []).isEmpty)
    }

    @Test(
        "Placeholder letters skip leading articles",
        arguments: [
            ("The Matrix", "M"), ("A Quiet Place", "Q"), ("An Education", "E"), ("Up", "U"),
            ("300", "3"), ("the lake house", "L"), ("The", "T"), ("  ", "?"), ("(500) Days", "5"),
        ])
    func posterLetters(title: String, expected: String) {
        #expect(TitleDisplay.posterLetter(for: title) == expected)
    }

    @Test("IMDb links go to the title page when the ID is known, otherwise a search")
    func imdbLinks() {
        #expect(TitleDisplay.imdbURL(imdbID: "tt0410297", title: "x")?.absoluteString == "https://www.imdb.com/title/tt0410297/")
        let search = TitleDisplay.imdbURL(imdbID: nil, title: "Corner Gas")?.absoluteString
        #expect(search == "https://www.imdb.com/find/?q=Corner%20Gas")
        #expect(TitleDisplay.imdbURL(imdbID: "", title: "Up")?.absoluteString == "https://www.imdb.com/find/?q=Up")
    }

    @Test("Kid-friendly ratings")
    func kidFriendly() {
        let kidFriendly = FilmRating.allCases.filter(\.isKidFriendly)
        #expect(Set(kidFriendly) == [.g, .pg, .tvY, .tvG, .tvPG])
        #expect(TitleKind.movie.ratingOptions.contains(.pg13))
        #expect(!TitleKind.movie.ratingOptions.contains(.tv14))
        #expect(TitleKind.tvShow.ratingOptions.contains(.tv14))
        #expect(TitleKind.tvShow.directorLabel == "Creators")
    }

    @Test("Formats describe where a title lives")
    func formats() {
        #expect(MediaFormat.dvd.locationLabel == "Owned · DVD")
        #expect(MediaFormat.streaming.locationLabel == "Streaming")
        #expect(!MediaFormat.dvd.needsService)
        #expect(MediaFormat.dvd.allowedServices.isEmpty)
        #expect(MediaFormat.streaming.allowedServices.contains(.netflix))
        #expect(!MediaFormat.digital.allowedServices.contains(.netflix))
        #expect(MediaFormat.digital.note(service: .plex) == "Digital copy you own on Plex")
        #expect(MediaFormat.streaming.note(service: .netflix) == "Included with Netflix — could leave the service")
        #expect(StreamingService.amazonPrime.shortName == "Prime")
    }

    @Test("A DVD never keeps a service")
    @MainActor
    func dvdDropsService() {
        let title = OwnedTitle(movie: TestSupport.movie(), format: .dvd, service: .netflix)
        #expect(title.service == nil)
        let streaming = OwnedTitle(movie: TestSupport.movie(), format: .streaming, service: .netflix)
        #expect(streaming.service == .netflix)
    }

    @Test("Shelf entries copy the catalog movie's details")
    @MainActor
    func copiesCatalogDetails() {
        let movie = TestSupport.movie(id: 42, title: "The Copy", genres: ["Drama"])
        let title = OwnedTitle(movie: movie, format: .digital, service: .plex)
        #expect(title.catalogID == 42)
        #expect(title.title == "The Copy")
        #expect(title.kind == .movie)
        #expect(title.genres == ["Drama"])
        #expect(title.moods == [.cozy])
        #expect(title.posterLetter == "C")
        #expect(!title.isReviewed)
    }

    @Test("Friend initials")
    func initials() {
        #expect(FriendReview.samples.map(\.initials) == ["TJ", "RN", "GB"])
    }
}

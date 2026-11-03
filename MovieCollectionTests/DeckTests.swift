//
//  DeckTests.swift
//  MovieCollectionTests
//
//  Purpose: The flip-card viewer: flipping, next/previous, and what happens
//  at the ends of the deck or when a title is removed.
//

import Foundation
import SwiftData
import Testing

@testable import MovieCollection

@Suite("Flip-card deck")
@MainActor
struct TitleDeckViewModelTests {

    /// A deck of the first five shelf titles, starting at the given position.
    private func makeDeck(startAt index: Int = 0) async throws -> (TitleDeckViewModel, [OwnedTitle]) {
        let appModel = try await TestSupport.makeAppModel()
        let titles = Array(appModel.titles.prefix(5))
        let deck = TitleDeckViewModel(
            ids: titles.map(\.persistentModelID),
            startID: titles[index].persistentModelID,
            appModel: appModel
        )
        return (deck, titles)
    }

    @Test("Tapping the centered card flips it, and tapping again flips it back")
    func flips() async throws {
        let (deck, titles) = try await makeDeck()
        #expect(!deck.isFlipped(titles[0]))
        deck.tap(titles[0])
        #expect(deck.isFlipped(titles[0]))
        #expect(deck.isCurrentFlipped)
        deck.tap(titles[0])
        #expect(!deck.isFlipped(titles[0]))
    }

    @Test("Tapping a peeking neighbor moves to it instead of flipping")
    func tapNeighbor() async throws {
        let (deck, titles) = try await makeDeck()
        deck.tap(titles[1])
        #expect(deck.currentID == titles[1].persistentModelID)
        #expect(!deck.isFlipped(titles[1]))
    }

    @Test("Next and previous step through the deck and stop at the ends")
    func nextAndPrevious() async throws {
        let (deck, titles) = try await makeDeck()
        #expect(deck.positionLabel == "1 of 5")
        #expect(!deck.canGoPrevious)
        #expect(deck.canGoNext)

        deck.goPrevious()  // Already at the start: stays put.
        #expect(deck.currentID == titles[0].persistentModelID)

        for _ in 0..<10 { deck.goNext() }  // More presses than cards.
        #expect(deck.currentID == titles[4].persistentModelID)
        #expect(deck.positionLabel == "5 of 5")
        #expect(!deck.canGoNext)

        deck.goPrevious()
        #expect(deck.positionLabel == "4 of 5")
    }

    @Test("Moving to another card turns the flipped one back to its poster")
    func moveResetsFlip() async throws {
        let (deck, titles) = try await makeDeck(startAt: 2)
        deck.tap(titles[2])
        #expect(deck.isFlipped(titles[2]))
        deck.goNext()
        #expect(!deck.isFlipped(titles[2]))
        #expect(!deck.isCurrentFlipped)
    }

    @Test("Swiping (setting the scroll position) also resets the flip")
    func swipeResetsFlip() async throws {
        let (deck, titles) = try await makeDeck()
        deck.tap(titles[0])
        deck.currentID = titles[3].persistentModelID
        #expect(deck.flippedID == nil)
        #expect(deck.positionLabel == "4 of 5")
    }

    @Test("A title removed from the shelf drops out, and the deck recovers")
    func removedTitle() async throws {
        let (deck, titles) = try await makeDeck(startAt: 1)
        deck.appModel.remove(titles[1])
        #expect(deck.titles.count == 4)
        #expect(deck.positionLabel == "")

        deck.recoverIfCurrentRemoved()
        #expect(deck.currentID == titles[0].persistentModelID)
        #expect(deck.positionLabel == "1 of 4")
    }

    @Test("Runtime text", arguments: [(45, "45m"), (60, "1h"), (99, "1h 39m"), (140, "2h 20m")])
    func runtimeText(minutes: Int, expected: String) {
        #expect(TitleDisplay.runtimeText(minutes: minutes) == expected)
    }
}

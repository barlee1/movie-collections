//
//  NavigationAndControlTests.swift
//  MovieCollectionTests
//
//  Purpose: Per-tab navigation (including the "Pick another" crash fix)
//  and the half-star picker's touch math.
//

import Foundation
import SwiftData
import SwiftUI
import Testing

@testable import MovieCollection

@Suite("Navigation")
@MainActor
struct AppRouterTests {

    @Test("Each tab keeps its own back history, and tapping a tab resets it")
    func perTabStacks() async throws {
        let appModel = try await TestSupport.makeAppModel()
        let id = try #require(appModel.titles.first).persistentModelID
        let router = AppRouter()

        router.push(.titleDetail(id))
        router.push(.friends)
        #expect(router.path(for: .shelf).wrappedValue.count == 2)
        #expect(router.path(for: .profile).wrappedValue.isEmpty)

        router.pop()
        #expect(router.path(for: .shelf).wrappedValue == [.titleDetail(id)])

        router.select(.profile)
        #expect(router.selectedTab == .profile)
        router.push(.friends)
        router.select(.shelf)
        #expect(router.path(for: .shelf).wrappedValue.isEmpty, "Tapping a tab returns it to its first screen")
    }

    @Test("Replacing the top screen swaps it without growing the history")
    func replaceTop() async throws {
        // Regression test: this used to crash with an exclusive-access violation.
        let appModel = try await TestSupport.makeAppModel()
        let first = appModel.titles[0].persistentModelID
        let second = appModel.titles[1].persistentModelID
        let router = AppRouter()
        router.select(.tonight)

        router.replaceTop(with: .titleDetail(first, fromTonight: true))
        #expect(router.path(for: .tonight).wrappedValue == [.titleDetail(first, fromTonight: true)])

        router.replaceTop(with: .titleDetail(second, fromTonight: true))
        #expect(router.path(for: .tonight).wrappedValue == [.titleDetail(second, fromTonight: true)])
    }

    @Test("Popping an empty stack does nothing")
    func popEmpty() {
        let router = AppRouter()
        router.pop()
        #expect(router.path(for: .shelf).wrappedValue.isEmpty)
    }
}

@Suite("Half-star picker")
@MainActor
struct HalfStarPickerTests {

    @Test(
        "Touches map to half stars: left half of a star is x.5, right half is whole",
        arguments: [
            (0.0, 0.5), (19.0, 0.5), (21.0, 1.0), (41.0, 1.5), (100.0, 2.5), (179.0, 4.5), (181.0, 5.0),
            (260.0, 5.0), (-10.0, 0.5),
        ])
    func touchMapping(x: Double, expected: Double) {
        // Five 40pt stars.
        #expect(HalfStarPicker.rating(at: x, width: 200) == expected)
    }

    @Test("A zero-width picker falls back to the minimum")
    func zeroWidth() {
        #expect(HalfStarPicker.rating(at: 50, width: 0) == 0.5)
    }

    @Test("VoiceOver reads ratings naturally")
    func accessibilityText() {
        #expect(StarRatingView.accessibilityText(for: 3.5) == "3.5 out of 5 stars")
        #expect(StarRatingView.accessibilityText(for: 4) == "4 out of 5 stars")
        #expect(StarRatingView.accessibilityText(for: 0) == "Not rated")
    }
}

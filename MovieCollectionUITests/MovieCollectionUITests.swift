//
//  MovieCollectionUITests.swift
//  MovieCollectionUITests
//
//  Created by Kylee Brown on 10/6/26.
//
//  Purpose: End-to-end flows through the real app. Each test launches with
//  "-UITesting", which gives the app a fresh in-memory shelf and settings
//  and turns off TMDB, so real saved data is never touched.
//

import XCTest

final class MovieCollectionUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Launches as the sample user with the 30-title sample shelf, skipping onboarding.
    @MainActor
    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication(bundleIdentifier: "brownk1.MovieCollection")
        app.launchArguments = ["-UITesting", "-SampleShelf"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Your shelf"].waitForExistence(timeout: 10), "The shelf should load")
        return app
    }

    // MARK: - Guest, then sign in

    @MainActor
    func testTryWithOwnMoviesThenSignIn() throws {
        let app = XCUIApplication(bundleIdentifier: "brownk1.MovieCollection")
        app.launchArguments = ["-UITesting"]
        app.launch()

        // A first launch opens to an empty shelf: no sample data, no sign-in.
        XCTAssertTrue(app.staticTexts["Your shelf is empty"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["0 titles · 0 not reviewed yet"].exists)

        // Add their own movie as a guest.
        app.buttons["Add your first movie"].tap()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Type it in'")).firstMatch.tap()
        let titleField = app.textFields["addTitle.title"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 3))
        titleField.tap()
        titleField.typeText("shrek")
        let suggestion = app.buttons["addTitle.suggestion"].firstMatch
        XCTAssertTrue(suggestion.waitForExistence(timeout: 3))
        suggestion.tap()
        app.buttons["Add to shelf"].tap()
        XCTAssertTrue(app.staticTexts["Title: Shrek"].waitForExistence(timeout: 3))

        // Profile needs a profile, so it shows the sign-in page.
        app.buttons["Profile"].tap()
        let continueButton = app.buttons["Continue"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 3))
        XCTAssertFalse(continueButton.isEnabled, "A name is required")
        let name = app.textFields["signIn.name"]
        name.tap()
        name.typeText("Sam Rivera")
        continueButton.tap()

        // Pick a service, then sign in.
        XCTAssertTrue(app.staticTexts["Your streaming services"].waitForExistence(timeout: 3))
        app.switches["Hulu"].tap()
        app.buttons["Sign in"].tap()

        // Signed in: Profile shows them, and the movie they added is still there.
        XCTAssertTrue(app.staticTexts["Sam Rivera"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Hulu"].exists)
        app.buttons["Shelf"].tap()
        XCTAssertTrue(app.staticTexts["1 title · 1 not reviewed yet"].waitForExistence(timeout: 3))
    }

    // MARK: - Tabs

    @MainActor
    func testEachTabShowsItsScreen() throws {
        let app = launchApp()
        let screens = [
            ("Tonight", "Tonight"),
            ("Add", "Add films"),
            ("Reviews", "Your Reviews"),
            ("Profile", "Ella Lauren"),
            ("Shelf", "Your shelf"),
        ]
        for (tab, heading) in screens {
            app.buttons[tab].tap()
            XCTAssertTrue(app.staticTexts[heading].waitForExistence(timeout: 3), "\(tab) should show \(heading)")
        }
        XCTAssertTrue(app.staticTexts["30 titles · 28 not reviewed yet"].exists)
    }

    // MARK: - Add, review, and see it on Reviews

    @MainActor
    func testAddMovieReviewItAndSeeItOnReviews() throws {
        let app = launchApp()

        // Add > Type it in
        app.buttons["Add"].tap()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Type it in'")).firstMatch.tap()

        // Type part of a title and pick the catalog suggestion.
        let titleField = app.textFields["addTitle.title"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 3))
        titleField.tap()
        titleField.typeText("shrek")
        let suggestion = app.buttons["addTitle.suggestion"].firstMatch
        XCTAssertTrue(suggestion.waitForExistence(timeout: 3))
        suggestion.tap()
        XCTAssertEqual(app.textFields["addTitle.title"].value as? String, "Shrek")

        // Save; the new title's detail screen opens.
        app.buttons["Add to shelf"].tap()
        XCTAssertTrue(app.staticTexts["Title: Shrek"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Owned · DVD"].exists)

        // Scroll the progress rows clear of the tab bar before tapping them.
        app.scrollViews.firstMatch.swipeUp()

        // Check off Watched right on the detail screen, no Edit needed.
        let watched = app.switches["Watched"]
        XCTAssertTrue(watched.waitForExistence(timeout: 3))
        XCTAssertEqual(watched.value as? String, "0")
        watched.tap()
        XCTAssertEqual(watched.value as? String, "1")

        // Check off Reviewed, then rate it 4.5 stars inline.
        app.switches["Reviewed"].tap()
        let rating = app.descendants(matching: .any)["detail.rating"]
        XCTAssertTrue(rating.waitForExistence(timeout: 3))
        // The left half of the fifth star picks 4.5.
        rating.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5)).tap()
        XCTAssertEqual(rating.value as? String, "4.5 out of 5 stars")

        // Add a written note in the review-only sheet.
        app.buttons["Add a note"].tap()
        XCTAssertTrue(app.navigationBars["Review"].waitForExistence(timeout: 3), "Opens the note sheet, not Edit")
        XCTAssertFalse(app.staticTexts["FORMAT"].exists, "The note sheet doesn't show the movie's details")
        let reviewText = app.descendants(matching: .any)["reviewNote.text"]
        XCTAssertTrue(reviewText.waitForExistence(timeout: 3))
        reviewText.tap()
        reviewText.typeText("Better out than in.")
        app.buttons["Save"].tap()

        // The note now shows on the detail screen.
        XCTAssertTrue(app.buttons["Edit note"].waitForExistence(timeout: 3))

        // It shows on the Reviews tab, and the shelf count updated.
        app.buttons["Reviews"].tap()
        XCTAssertTrue(app.staticTexts["Shrek"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Better out than in."].exists)

        app.buttons["Shelf"].tap()
        XCTAssertTrue(app.staticTexts["31 titles · 28 not reviewed yet"].waitForExistence(timeout: 3))
    }

    // MARK: - Flip cards

    @MainActor
    func testFlipCardAndStepThroughDeck() throws {
        let app = launchApp()

        // Tapping a shelf poster opens the flip-card viewer.
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Apollo 13'")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["1 of 30"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["Previous title"].isEnabled, "Can't go back from the first card")

        // Tapping the card flips it to its details.
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH 'Apollo 13,'"))
            .firstMatch
            .tap()
        XCTAssertTrue(app.staticTexts["Director: Ron Howard"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Tap the card to see the poster"].exists)

        // Next moves to the second card, on its poster side.
        app.buttons["Next title"].tap()
        XCTAssertTrue(app.staticTexts["2 of 30"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Tap the card to flip it"].exists)
        XCTAssertTrue(app.buttons["Previous title"].isEnabled)

        app.buttons["Previous title"].tap()
        XCTAssertTrue(app.staticTexts["1 of 30"].waitForExistence(timeout: 3))
    }

    // MARK: - Add tab features

    @MainActor
    func testImportSampleSpreadsheet() throws {
        let app = launchApp()
        app.buttons["Add"].tap()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Import a spreadsheet'")).firstMatch.tap()

        app.buttons["Try the sample spreadsheet"].tap()
        XCTAssertTrue(app.staticTexts["8 TITLES FOUND"].waitForExistence(timeout: 3))
        // Toy Story is already on the shelf, so only 7 are checked.
        app.buttons["Add 7 titles"].tap()
        XCTAssertTrue(app.staticTexts["Added 7 titles"].waitForExistence(timeout: 3))

        app.buttons["See your shelf"].tap()
        XCTAssertTrue(app.staticTexts["37 titles · 35 not reviewed yet"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testScanSampleCoverAndAddIt() throws {
        let app = launchApp()
        app.buttons["Add"].tap()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Scan a cover'")).firstMatch.tap()

        // The sample case is read on device with Vision and matched to the catalog.
        app.buttons["Try a sample"].tap()
        let add = app.buttons["Add The Prestige"]
        XCTAssertTrue(add.waitForExistence(timeout: 10))
        add.tap()

        // The add form opens already filled in.
        XCTAssertEqual(app.textFields["addTitle.title"].value as? String, "The Prestige")
        app.buttons["Add to shelf"].tap()
        XCTAssertTrue(app.staticTexts["Title: The Prestige"].waitForExistence(timeout: 3))
    }

    // MARK: - Profile

    @MainActor
    func testEditStreamingServices() throws {
        let app = launchApp()
        app.buttons["Profile"].tap()
        XCTAssertTrue(app.staticTexts["Netflix"].waitForExistence(timeout: 3))

        // Add Hulu and remove Netflix.
        app.buttons["Edit streaming services"].tap()
        let hulu = app.switches["Hulu"]
        XCTAssertTrue(hulu.waitForExistence(timeout: 3))
        hulu.tap()
        app.switches["Netflix"].tap()
        app.buttons["Save"].tap()

        XCTAssertTrue(app.staticTexts["Hulu"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["Netflix"].exists)
        XCTAssertTrue(app.staticTexts["Amazon Prime"].exists)
    }

    // MARK: - Tonight

    @MainActor
    func testTonightPickAndPickAnother() throws {
        let app = launchApp()
        app.buttons["Tonight"].tap()

        app.buttons["Pick one for me"].tap()
        XCTAssertTrue(app.staticTexts["Tonight's pick"].waitForExistence(timeout: 3))

        // This used to crash; it should swap in another pick.
        let pickAnother = app.buttons["Pick another"]
        XCTAssertTrue(pickAnother.waitForExistence(timeout: 3))
        pickAnother.tap()
        XCTAssertTrue(app.staticTexts["Tonight's pick"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.state, .runningForeground)

        // Back goes to Tonight, not to the previous pick.
        app.buttons["Back"].tap()
        XCTAssertTrue(app.buttons["Pick one for me"].waitForExistence(timeout: 3))
    }
}

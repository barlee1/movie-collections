//
//  AppRouter.swift
//  MovieCollection
//
//  Purpose: Tracks the selected tab and gives each tab its own navigation
//  stack, so back buttons return to the right place within that tab.
//  Used in: RootTabView (owner), any view that navigates.
//

import SwiftData
import SwiftUI

/// Screens that get pushed on top of a tab's root screen.
enum Route: Hashable {
    /// A title's detail screen. `fromTonight` shows the "Tonight's pick"
    /// tag and the "Pick another" button. `fromShelf` zooms it in from the
    /// tapped Shelf poster.
    case titleDetail(PersistentIdentifier, fromTonight: Bool = false, fromShelf: Bool = false)
    /// The user's reviews opened from a detail screen's "See Review", scrolled to that title.
    case reviews(highlighting: PersistentIdentifier)
    /// The "Type it in" form, optionally pre-filled from a catalog movie (by TMDB ID).
    case addTitle(prefillMovieID: Int? = nil)
    /// Read a title off a case with the camera or a photo.
    case scanCover
    /// Add titles from a CSV spreadsheet.
    case importSpreadsheet
    /// Bring in ratings and watch dates from a Letterboxd export.
    case importLetterboxd
    case friends
    /// Account, streaming services, data, and About, opened from Profile's gear.
    case settings
    /// Settings › Locations: places a disc can be.
    case manageLocations
    /// Settings › Tags.
    case manageTags
    /// Settings › Family: the people the user watches with.
    case manageFamily
}

@Observable
final class AppRouter {
    var selectedTab: AppTab = .shelf
    private var paths: [AppTab: [Route]] = [:]

    /// Switches tabs. Like the design, tapping a tab always returns
    /// that tab to its root screen.
    func select(_ tab: AppTab) {
        paths[tab] = []
        selectedTab = tab
    }

    /// Pushes a screen onto the current tab's stack.
    func push(_ route: Route) {
        paths[selectedTab, default: []].append(route)
    }

    /// Goes back one screen in the current tab.
    func pop() {
        _ = paths[selectedTab]?.popLast()
    }

    /// Swaps the top screen for another without adding to the back history.
    /// Used by Tonight's "Pick another".
    func replaceTop(with route: Route) {
        // Work on a copy: reading and writing `paths` in one statement is an
        // exclusive-access violation in Swift.
        var path = paths[selectedTab, default: []]
        if path.isEmpty {
            path.append(route)
        } else {
            path[path.count - 1] = route
        }
        paths[selectedTab] = path
    }

    /// The navigation path binding for one tab's NavigationStack.
    func path(for tab: AppTab) -> Binding<[Route]> {
        Binding(
            get: { self.paths[tab, default: []] },
            set: { self.paths[tab] = $0 }
        )
    }
}

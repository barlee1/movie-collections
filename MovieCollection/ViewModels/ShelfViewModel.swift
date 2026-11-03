//
//  ShelfViewModel.swift
//  MovieCollection
//
//  Purpose: State for the Shelf tab: the standard iOS search (one box that
//  searches title, director, cast, genre, year, and tags, plus suggestion tokens),
//  the review scopes, the filter sheet, and the sort order.
//  Used in: ShelfView, ShelfFilterSheet.
//

import Foundation
import Observation

/// How the shelf is ordered. Saved between launches by AppViewModel.
enum ShelfSortOrder: String, CaseIterable, Identifiable {
    case aToZ = "A to Z"
    case lastWatched = "Last watched"
    case recentlyAdded = "Recently added"
    case yourRating = "Your rating"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .aToZ: "textformat"
        case .lastWatched: "calendar"
        case .recentlyAdded: "clock"
        case .yourRating: "star"
        }
    }

    /// The short note under the title, e.g. "Sorted by last watched". A to Z is the default, so it has none.
    var summary: String? {
        self == .aToZ ? nil : "Sorted by \(rawValue.lowercased())"
    }
}

/// A search term picked from the suggestions, shown as a chip in the search field.
struct ShelfSearchToken: Identifiable, Hashable {
    enum Kind: String {
        case director = "Director"
        case cast = "Cast"
        case genre = "Genre"
        case year = "Year"
        case tag = "Tag"

        var systemImage: String {
            switch self {
            case .director: "megaphone"
            case .cast: "person"
            case .genre: "theatermasks"
            case .year: "calendar"
            case .tag: "tag"
            }
        }
    }

    let kind: Kind
    let value: String

    var id: String { "\(kind.rawValue):\(value)" }
    /// e.g. "Director: Christopher Nolan"
    var label: String { "\(kind.rawValue): \(value)" }
}

@Observable
final class ShelfViewModel {

    /// The All / Not reviewed / Reviewed scopes.
    enum SeenFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case notReviewed = "Not reviewed"
        case reviewed = "Reviewed"

        var id: String { rawValue }
    }

    /// Everything set in the filter sheet.
    struct Filters: Equatable {
        var formats: Set<MediaFormat> = []
        var services: Set<StreamingService> = []
        var ratings: Set<FilmRating> = []
        /// Discs in any of these places (by `StorageLocation.id`).
        var locationIDs: Set<UUID> = []
        /// Titles with any of these tags (by `Tag.id`).
        var tagIDs: Set<UUID> = []

        /// How many filters are on, shown as the badge on the Filter button.
        var activeCount: Int { formats.count + services.count + ratings.count + locationIDs.count + tagIDs.count }
    }

    var seen: SeenFilter = .all
    /// The search field's text.
    var query = ""
    var tokens: [ShelfSearchToken] = []
    var filters = Filters()
    var isFilterSheetOpen = false
    /// Whether the search field is active (from the Search button or pulling the shelf down).
    var isSearchPresented = false

    let appModel: AppViewModel

    init(appModel: AppViewModel) {
        self.appModel = appModel
    }

    /// Saved by AppViewModel so it's remembered between launches.
    var sortOrder: ShelfSortOrder {
        get { appModel.shelfSortOrder }
        set { appModel.shelfSortOrder = newValue }
    }

    // MARK: - Results

    /// The shelf as searched, filtered, and sorted. The flip-card viewer
    /// steps through titles in this same order.
    var visibleTitles: [OwnedTitle] {
        Self.sorted(appModel.titles.filter(matches), by: sortOrder)
    }

    /// Whether any search text, token, scope, or filter is narrowing the shelf.
    var isNarrowed: Bool {
        !query.trimmed.isEmpty || !tokens.isEmpty || seen != .all || filters.activeCount > 0
    }

    private func matches(_ title: OwnedTitle) -> Bool {
        switch seen {
        case .all: break
        case .notReviewed: if title.isReviewed { return false }
        case .reviewed: if !title.isReviewed { return false }
        }
        if !filters.formats.isEmpty, !filters.formats.contains(title.format) { return false }
        if !filters.services.isEmpty {
            guard let service = title.service, filters.services.contains(service) else { return false }
        }
        if !filters.ratings.isEmpty {
            guard let rating = title.filmRating, filters.ratings.contains(rating) else { return false }
        }
        if !filters.locationIDs.isEmpty {
            guard let location = title.storageLocation, filters.locationIDs.contains(location.id) else { return false }
        }
        if !filters.tagIDs.isEmpty, !title.tags.contains(where: { filters.tagIDs.contains($0.id) }) { return false }
        if !tokens.allSatisfy({ Self.title(title, matches: $0) }) { return false }
        return Self.title(title, containsText: query)
    }

    /// One search box for everything: title, director, cast, genres, year, and tags.
    private static func title(_ title: OwnedTitle, containsText text: String) -> Bool {
        let search = text.trimmed
        guard !search.isEmpty else { return true }
        let fields = [title.title, title.director, title.year.map(String.init) ?? ""] + title.cast + title.genres + title.tags.map(\.name)
        return fields.contains { $0.localizedStandardContains(search) }
    }

    private static func title(_ title: OwnedTitle, matches token: ShelfSearchToken) -> Bool {
        switch token.kind {
        case .director: names(in: title.director).contains(token.value)
        case .cast: title.cast.contains(token.value)
        case .genre: title.genres.contains(token.value)
        case .year: title.year.map(String.init) == token.value
        case .tag: title.tags.contains { $0.name == token.value }
        }
    }

    /// Directors are stored as one string, e.g. "Andrew Adamson, Vicky Jenson".
    private static func names(in text: String) -> [String] {
        text.split(separator: ",").map { String($0).trimmed }.filter { !$0.isEmpty }
    }

    // MARK: - Sorting

    static func sorted(_ titles: [OwnedTitle], by order: ShelfSortOrder) -> [OwnedTitle] {
        titles.sorted { first, second in
            switch order {
            case .aToZ:
                return alphabetical(first, second)
            case .lastWatched:
                // Never-watched titles first, then the longest since watching.
                switch (first.lastWatched, second.lastWatched) {
                case (nil, nil): return alphabetical(first, second)
                case (nil, _): return true
                case (_, nil): return false
                case let (firstDate?, secondDate?):
                    return firstDate == secondDate ? alphabetical(first, second) : firstDate < secondDate
                }
            case .recentlyAdded:
                return first.dateAdded == second.dateAdded ? alphabetical(first, second) : first.dateAdded > second.dateAdded
            case .yourRating:
                // Highest first; unrated titles at the end.
                let firstStars = first.review?.rating ?? -1
                let secondStars = second.review?.rating ?? -1
                return firstStars == secondStars ? alphabetical(first, second) : firstStars > secondStars
            }
        }
    }

    /// A to Z ignoring "The", "A", and "An".
    private static func alphabetical(_ first: OwnedTitle, _ second: OwnedTitle) -> Bool {
        TitleDisplay.sortKey(for: first.title).localizedStandardCompare(TitleDisplay.sortKey(for: second.title)) == .orderedAscending
    }

    // MARK: - Suggestions

    /// Directors, cast, genres, and years on the shelf that match the typed
    /// text, offered as tokens while searching. Most specific first.
    var suggestions: [ShelfSearchToken] {
        let search = query.trimmed
        guard search.count >= 2 else { return [] }
        let titles = appModel.titles
        var found: [ShelfSearchToken] = []

        func add(_ kind: ShelfSearchToken.Kind, _ values: [String]) {
            for value in Set(values).sorted() where value.localizedStandardContains(search) {
                let token = ShelfSearchToken(kind: kind, value: value)
                if !tokens.contains(token), !found.contains(token) { found.append(token) }
            }
        }
        add(.tag, appModel.tags.map(\.name))
        add(.genre, titles.flatMap(\.genres))
        add(.director, titles.flatMap { Self.names(in: $0.director) })
        add(.cast, titles.flatMap(\.cast))
        add(.year, titles.compactMap { $0.year.map(String.init) })
        return Array(found.prefix(Self.suggestionLimit))
    }

    static let suggestionLimit = 6

    // MARK: - Labels

    /// e.g. "30 titles · 28 not reviewed yet"
    var subtitle: String {
        let total = appModel.titles.count
        let notReviewed = appModel.titles.filter { !$0.isReviewed }.count
        return "\(total) \(total == 1 ? "title" : "titles") · \(notReviewed) not reviewed yet"
    }

    /// e.g. "Show 12 titles"
    var showResultsLabel: String {
        let count = visibleTitles.count
        return "Show \(count) \(count == 1 ? "title" : "titles")"
    }

    /// The details line on a shelf card: year, then the user's stars if reviewed
    /// (otherwise the film rating), then the service.
    static func meta(for title: OwnedTitle) -> String {
        let ratingPart: String? =
            if let review = title.review {
                "\(review.rating.starText)/5"
            } else {
                title.filmRating?.label
            }
        let parts: [String?] = [
            title.year.map(String.init),
            ratingPart,
            title.format == .dvd ? nil : title.service?.shortName,
        ]
        return parts.compactMap { $0 }.joined(separator: " · ")
    }

    // MARK: - Filter options

    /// Services on the shelf plus the user's subscriptions.
    var serviceOptions: [StreamingService] {
        let used = Set(appModel.titles.compactMap(\.service)).union(appModel.subscriptions)
        return StreamingService.allCases.filter(used.contains)
    }

    /// Places that have at least one disc, in the user's order.
    var locationOptions: [StorageLocation] {
        appModel.locations.filter { !$0.titles.isEmpty }
    }

    /// Tags used on at least one title.
    var tagOptions: [Tag] {
        appModel.tags.filter { !$0.titles.isEmpty }
    }

    /// Film ratings that appear on the shelf.
    var ratingOptions: [FilmRating] {
        let used = Set(appModel.titles.compactMap(\.filmRating))
        return FilmRating.allCases.filter(used.contains)
    }

    /// Clears the filter sheet's choices.
    func clearFilters() {
        filters = Filters()
    }

    /// Clears the search, tokens, scope, and filters, showing the whole shelf.
    func showEverything() {
        query = ""
        tokens = []
        seen = .all
        filters = Filters()
    }
}

extension String {
    /// The string without leading or trailing spaces and newlines.
    nonisolated var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

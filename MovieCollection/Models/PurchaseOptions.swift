//
//  PurchaseOptions.swift
//  MovieCollection
//
//  Purpose: Ways to own a movie the user only streams, for the detail
//  screen's "Own it instead" card: the digital stores that sell it in the
//  user's country (from TMDB's JustWatch data), plus search links for eBay
//  and the stores, which work even without that data.
//  Used in: TMDBClient, AppViewModel, OwnItInsteadCard.
//

import Foundation

/// Where a movie is sold digitally in one country.
nonisolated struct PurchaseOptions: Sendable, Equatable {
    struct Store: Sendable, Equatable, Identifiable {
        /// TMDB's provider ID, e.g. 2 for Apple TV Store.
        let id: Int
        let name: String
    }

    /// Digital stores that sell it, most popular first. Empty means it can't be bought.
    let stores: [Store]
    /// The ISO country code the stores are for, e.g. "US".
    let region: String
    /// TMDB's "where to watch" page for the movie, with links to every store.
    let watchPageURL: URL?

    var isBuyable: Bool { !stores.isEmpty }
}

/// Search links for buying a title. Searches rather than product pages, since
/// TMDB doesn't give per-store links; they also work for hand-entered titles.
nonisolated enum OwnItLinks {
    /// The user's country for where-to-buy data, falling back to the US.
    static var region: String { Locale.current.region?.identifier ?? "US" }

    /// An eBay search for a used or new disc, e.g. "Inception 2010 DVD Blu-ray".
    static func eBayURL(title: String, year: Int?) -> URL? {
        search("https://www.ebay.com/sch/i.html", key: "_nkw", text: query(title, year) + " DVD Blu-ray")
    }

    /// A store's own search for the movie. US store sites only; other countries,
    /// and stores the app doesn't know, use TMDB's watch page instead.
    static func storeURL(for store: PurchaseOptions.Store, title: String, year: Int?, region: String, watchPage: URL?) -> URL? {
        guard region == "US", let searchURL = storeSearchURL(storeID: store.id, text: query(title, year)) else {
            return watchPage
        }
        return searchURL
    }

    /// Stores to suggest when where-to-buy data isn't available, as (name, search link).
    static func fallbackStores(title: String, year: Int?) -> [(name: String, url: URL)] {
        let text = query(title, year)
        return [(2, "Apple TV"), (10, "Amazon")].compactMap { id, name in
            storeSearchURL(storeID: id, text: text).map { (name, $0) }
        }
    }

    // MARK: - Building links

    private static func storeSearchURL(storeID: Int, text: String) -> URL? {
        switch storeID {
        case 2: search("https://tv.apple.com/search", key: "term", text: text)
        case 3: search("https://play.google.com/store/search", key: "q", text: text, extra: ["c": "movies"])
        case 7: search("https://athome.fandango.com/content/browse/search", key: "searchString", text: text)
        case 10: search("https://www.amazon.com/s", key: "k", text: text, extra: ["i": "instant-video"])
        case 192: search("https://www.youtube.com/results", key: "search_query", text: text)
        default: nil
        }
    }

    private static func query(_ title: String, _ year: Int?) -> String {
        [title, year.map(String.init)].compactMap { $0 }.joined(separator: " ")
    }

    private static func search(_ base: String, key: String, text: String, extra: [String: String] = [:]) -> URL? {
        var components = URLComponents(string: base)
        components?.queryItems =
            [URLQueryItem(name: key, value: text)]
            + extra.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        return components?.url
    }
}

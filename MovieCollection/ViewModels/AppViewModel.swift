//
//  AppViewModel.swift
//  MovieCollection
//
//  Purpose: App-wide state shared by every screen: the movie catalog, the
//  shelf, and the user's profile. Loads the catalog at launch, searches TMDB
//  for movies beyond it, and is the one path screens use to change saved
//  data, so every screen sees changes immediately.
//  Used in: MovieCollectionApp (injected into the environment), screen ViewModels.
//

import Foundation
import Observation
import SwiftData

@Observable
final class AppViewModel {

    enum LoadState: Equatable {
        case loading
        case ready
        case failed(String)
    }

    /// The bundled movies: always available, even offline.
    private(set) var catalog: [Movie] = []
    private(set) var loadState: LoadState = .loading
    /// Every title on the shelf, sorted by title.
    private(set) var titles: [OwnedTitle] = []
    /// The user's tags, A to Z.
    private(set) var tags: [Tag] = []
    /// Places a disc can be, in the user's order. Shelf and Loaned out are always here.
    private(set) var locations: [StorageLocation] = []
    /// The people the user watches with, in the user's order. At most `FamilyMember.limit`.
    private(set) var familyMembers: [FamilyMember] = []
    /// Set when saving fails; ContentView shows it in an alert.
    var errorMessage: String?

    let store: CollectionStore

    /// The user's saved profile, or nil until onboarding is finished.
    private(set) var profile: UserProfile?

    /// Movies from TMDB this session (search summaries, replaced by full
    /// details once fetched), by ID, so routes and repeat lookups don't
    /// need the network again.
    private(set) var fetchedMovies: [Int: Movie] = [:]

    /// Where-to-buy results this session, by "movieID-region", so revisiting
    /// a detail screen doesn't need the network again.
    @ObservationIgnored private var purchaseOptionsCache: [String: PurchaseOptions] = [:]

    @ObservationIgnored private let catalogService: MovieCatalogService
    @ObservationIgnored private let remoteCatalog: (any RemoteMovieCatalog)?
    @ObservationIgnored private let settings: UserDefaults
    /// Due-back notifications for loaned discs, kept in sync with the shelf.
    @ObservationIgnored let loanReminders: any LoanReminderScheduling
    /// How the Shelf is ordered, remembered between launches.
    var shelfSortOrder: ShelfSortOrder {
        didSet { settings.set(shelfSortOrder.rawValue, forKey: Self.shelfSortKey) }
    }
    static let shelfSortKey = "shelfSortOrder"
    /// Whether Tonight suggests film ratings from the youngest viewer's age.
    var suggestsRatingsFromAges: Bool {
        didSet { settings.set(suggestsRatingsFromAges, forKey: Self.ageSuggestionsKey) }
    }
    static let ageSuggestionsKey = "suggestsRatingsFromAges"
    /// Whether the user's own profile is listed with their family members.
    var includesYouInFamily: Bool {
        didSet { settings.set(includesYouInFamily, forKey: Self.includesYouKey) }
    }
    static let includesYouKey = "includesYouInFamily"
    /// Whether Streaming titles show the "Own it instead" card.
    var showsOwnItSuggestions: Bool {
        didSet { settings.set(showsOwnItSuggestions, forKey: Self.ownItKey) }
    }
    static let ownItKey = "showsOwnItSuggestions"

    /// Adds the sample shelf once the catalog loads. For previews and UI tests.
    @ObservationIgnored var loadsSampleShelfOnStart = false

    static let profileKey = "userProfile"
    /// Where subscriptions were saved before profiles existed. Read once to
    /// prefill onboarding for anyone upgrading from an early build.
    static let legacySubscriptionsKey = "ellaSubscriptions"

    /// - Parameters:
    ///   - remoteCatalog: Live movie search (TMDB). Nil uses only the bundled catalog.
    ///   - settings: Where the profile and small preferences are saved.
    init(
        store: CollectionStore,
        catalogService: MovieCatalogService = MovieCatalogService(),
        remoteCatalog: (any RemoteMovieCatalog)? = nil,
        settings: UserDefaults = .standard,
        loanReminders: any LoanReminderScheduling = NoLoanReminders()
    ) {
        self.loanReminders = loanReminders
        self.store = store
        self.catalogService = catalogService
        self.remoteCatalog = remoteCatalog
        self.settings = settings
        shelfSortOrder = settings.string(forKey: Self.shelfSortKey).flatMap(ShelfSortOrder.init(rawValue:)) ?? .aToZ
        suggestsRatingsFromAges = settings.object(forKey: Self.ageSuggestionsKey) as? Bool ?? true
        includesYouInFamily = settings.object(forKey: Self.includesYouKey) as? Bool ?? true
        showsOwnItSuggestions = settings.object(forKey: Self.ownItKey) as? Bool ?? true
        if let data = settings.data(forKey: Self.profileKey) {
            profile = try? JSONDecoder().decode(UserProfile.self, from: data)
        }
    }

    // MARK: - Profile

    /// True until the user signs in. Guests can use the shelf, Add, Tonight,
    /// and Reviews; Profile and Friends show the sign-in page instead.
    var isGuest: Bool { profile?.isGuest ?? true }

    /// The streaming services the user pays for, in the app's usual service order.
    var subscriptions: [StreamingService] { profile?.subscriptions ?? [] }

    /// Services to preselect in profile setup: ones saved by an early build if
    /// there are any, otherwise whatever is chosen now.
    var suggestedSubscriptions: [StreamingService] {
        let legacy = (settings.stringArray(forKey: Self.legacySubscriptionsKey) ?? []).compactMap(StreamingService.init(rawValue:))
        return legacy.isEmpty ? subscriptions : legacy
    }

    /// Replaces the whole profile. Used for the guest, the sample user, and tests.
    func setProfile(_ newProfile: UserProfile) {
        saveProfile(newProfile)
    }

    /// Signs the guest in with their own profile. Everything they added before
    /// signing in stays; the sample titles stay too unless they ask to remove them.
    func finishSetup(with newProfile: UserProfile, keepingSampleShelf: Bool) {
        var ownProfile = newProfile
        ownProfile.isGuest = false
        saveProfile(ownProfile)
        if !keepingSampleShelf { removeSampleShelf() }
    }

    /// Replaces the user's name and photo. Subscriptions are kept as they are.
    func updateProfile(_ edited: UserProfile) {
        guard var updated = profile, !edited.name.trimmed.isEmpty else { return }
        updated.name = edited.name
        updated.photoData = edited.photoData
        updated.photoAssetName = edited.photoAssetName
        saveProfile(updated)
    }

    /// Replaces the user's subscriptions and saves them, in the app's usual service order.
    func setSubscriptions(_ services: Set<StreamingService>) {
        guard var updated = profile else { return }
        updated.subscriptions = StreamingService.allCases.filter(services.contains)
        saveProfile(updated)
    }

    private func saveProfile(_ newProfile: UserProfile) {
        var cleaned = newProfile
        cleaned.name = newProfile.name.trimmed
        cleaned.subscriptions = StreamingService.allCases.filter(newProfile.subscriptions.contains)
        profile = cleaned
        do {
            settings.set(try JSONEncoder().encode(cleaned), forKey: Self.profileKey)
        } catch {
            errorMessage = "Couldn't save your profile: \(error.localizedDescription)"
        }
    }

    // MARK: - Sample shelf

    /// Whether all 30 sample titles are already on the shelf.
    var isSampleShelfLoaded: Bool { ShelfSeeder.isSampleShelfLoaded(in: titles) }

    /// Adds the sample titles that aren't on the shelf yet. Returns how many were added.
    @discardableResult
    func loadSampleShelf() -> Int {
        var added = 0
        _ = perform("load the sample shelf") {
            added = try ShelfSeeder.addSampleShelf(to: store, catalog: catalog)
        }
        return added
    }

    /// Whether any sample title is still on the shelf.
    var hasSampleTitles: Bool { ShelfSeeder.hasSampleTitles(in: titles) }

    /// Removes the sample titles, keeping anything the user added. Returns how many were removed.
    @discardableResult
    func removeSampleShelf() -> Int {
        var removed = 0
        _ = perform("remove the sample shelf") {
            removed = try ShelfSeeder.removeSampleShelf(from: store)
        }
        return removed
    }

    // MARK: - Deleting everything

    /// Removes every title, review, and family member, signs out to a fresh guest, and resets
    /// preferences, like a first launch. Returns false if the shelf couldn't be cleared.
    @discardableResult
    func deleteAllData() -> Bool {
        let cleared = perform("delete your data") {
            try store.deleteAllData()
        }
        guard cleared else { return false }
        settings.removeObject(forKey: Self.legacySubscriptionsKey)
        shelfSortOrder = .aToZ
        suggestsRatingsFromAges = true
        includesYouInFamily = true
        showsOwnItSuggestions = true
        saveProfile(.guest)
        return true
    }

    // MARK: - Launch

    /// Loads the catalog and the saved shelf. Safe to call more than once.
    /// On the very first launch the user becomes a guest with an empty
    /// shelf, so they can try the app with their own movies before signing in.
    func start() async {
        guard loadState != .ready else { return }
        loadState = .loading
        do {
            catalog = try await catalogService.loadMovies()
            if profile == nil {
                saveProfile(.guest)
            }
            if loadsSampleShelfOnStart {
                try ShelfSeeder.addSampleShelf(to: store, catalog: catalog)
            }
            // Version 1 shelves: last-watched dates become watch history, DVDs go on the Shelf.
            try store.upgradeLegacyData()
            try reloadShelf()
            loadState = .ready
        } catch {
            loadState = .failed(error.localizedDescription)
        }
    }

    private func reloadShelf() throws {
        titles = try store.allTitles()
        // Loans, returns, deleted titles, and deleting everything all land here.
        let loans = LoanReminder.reminders(for: titles)
        let reminders = loanReminders
        Task { await reminders.sync(loans) }
        tags = try store.allTags()
        locations = try store.allLocations()
        familyMembers = try store.allFamilyMembers()
    }

    // MARK: - Derived shelf values

    /// Titles watched at least once.
    var watchedCount: Int { titles.filter(\.isWatched).count }

    var movieCount: Int { titles.filter { $0.kind == .movie }.count }
    var tvShowCount: Int { titles.filter { $0.kind == .tvShow }.count }

    /// Reviewed titles, newest review first.
    var reviewedTitles: [OwnedTitle] {
        titles
            .filter(\.isReviewed)
            .sorted { ($0.review?.date ?? .distantPast) > ($1.review?.date ?? .distantPast) }
    }

    /// Looks up a shelf title by ID. Returns nil once it has been removed.
    func title(with id: PersistentIdentifier) -> OwnedTitle? {
        titles.first { $0.persistentModelID == id }
    }

    /// Whether a catalog movie is already on the shelf.
    func isOnShelf(catalogID: Int) -> Bool {
        titles.contains { $0.catalogID == catalogID }
    }

    /// Bundled catalog movies whose title contains the search text. Instant and offline.
    func catalogMatches(for query: String, limit: Int = 5) -> [Movie] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }
        return Array(catalog.filter { $0.title.localizedStandardContains(trimmed) }.prefix(limit))
    }

    // MARK: - Online catalog (TMDB)

    /// Whether live TMDB search is set up (a key is in Secrets.plist).
    var hasOnlineCatalog: Bool { remoteCatalog != nil }

    /// A movie from the bundled catalog or one fetched from TMDB this session.
    func movie(withID id: Int) -> Movie? {
        fetchedMovies[id] ?? catalog.first { $0.id == id }
    }

    /// Bundled matches first, then TMDB results that aren't already listed.
    /// Network problems are ignored, so search still works offline.
    func searchMovies(_ query: String, year: Int? = nil, limit: Int = 8) async -> [Movie] {
        let local = catalogMatches(for: query, limit: limit)
        guard let remoteCatalog, query.trimmed.count >= 2 else { return local }
        let remote = (try? await remoteCatalog.searchMovies(query.trimmed, year: year)) ?? []
        // Remember results so a route can open the add form with one by ID.
        for movie in remote where fetchedMovies[movie.id] == nil {
            fetchedMovies[movie.id] = movie
        }
        let localIDs = Set(local.map(\.id))
        return Array((local + remote.filter { !localIDs.contains($0.id) }).prefix(limit))
    }

    /// The movie with every detail filled in. Bundled and already-fetched
    /// movies return right away; TMDB search results are fetched once.
    /// Falls back to the movie as given if TMDB can't be reached.
    func fullDetails(for movie: Movie) async -> Movie {
        guard movie.isSummary else { return movie }
        if let fetched = fetchedMovies[movie.id], !fetched.isSummary { return fetched }
        guard let remoteCatalog, let details = try? await remoteCatalog.movieDetails(id: movie.id) else { return movie }
        fetchedMovies[details.id] = details
        return details
    }

    /// Where a movie can be bought in the user's country, from TMDB. Nil for
    /// titles without a TMDB ID, TV shows, or when TMDB can't be reached.
    func purchaseOptions(for title: OwnedTitle, region: String = OwnItLinks.region) async -> PurchaseOptions? {
        guard let remoteCatalog, title.kind == .movie, let movieID = title.catalogID else { return nil }
        let key = "\(movieID)-\(region)"
        if let cached = purchaseOptionsCache[key] { return cached }
        guard let options = try? await remoteCatalog.purchaseOptions(movieID: movieID, region: region) else { return nil }
        purchaseOptionsCache[key] = options
        return options
    }

    /// Finds one movie by title (and year, if known) on TMDB, with full details.
    /// Used for imported rows the bundled catalog doesn't have.
    func lookUpMovie(title: String, year: Int?) async -> Movie? {
        guard let remoteCatalog,
            let results = try? await remoteCatalog.searchMovies(title, year: year),
            let match = TitleMatcher.findMovie(title: title, year: year, in: results)
        else { return nil }
        let details = await fullDetails(for: match)
        return details.isSummary ? nil : details
    }

    // MARK: - Changing saved data

    /// Adds a title to the shelf. Returns false (and sets `errorMessage`) on failure.
    @discardableResult
    func add(_ title: OwnedTitle) -> Bool {
        perform("add \(title.title)") { try store.add(title) }
    }

    /// Removes a title and its review from the shelf.
    @discardableResult
    func remove(_ title: OwnedTitle) -> Bool {
        perform("remove \(title.title)") { try store.delete(title) }
    }

    /// Saves edits made directly to a title's properties.
    @discardableResult
    func saveChanges(to title: OwnedTitle) -> Bool {
        perform("save \(title.title)") { try store.save() }
    }

    /// Creates or updates the user's review of a title.
    @discardableResult
    func saveReview(for title: OwnedTitle, rating: Double, text: String, date: Date = .now) -> Bool {
        perform("save your review") { try store.saveReview(for: title, rating: rating, text: text, date: date) }
    }

    /// Removes the user's review of a title.
    @discardableResult
    func deleteReview(for title: OwnedTitle) -> Bool {
        perform("delete your review") { try store.deleteReview(for: title) }
    }

    /// Runs a store change, then refreshes the shelf so every screen updates.
    func perform(_ action: String, _ work: () throws -> Void) -> Bool {
        do {
            try work()
            try reloadShelf()
            return true
        } catch {
            errorMessage = "Couldn't \(action): \(error.localizedDescription)"
            return false
        }
    }
}

// MARK: - Display formatting

extension Date {
    /// Dates as shown across the app, e.g. "Sep 25, 2024".
    var displayText: String { formatted(date: .abbreviated, time: .omitted) }
}

extension Double {
    /// Star ratings without a trailing ".0", e.g. "4" or "3.5".
    var starText: String { formatted(.number.precision(.fractionLength(0...1))) }
}

extension Set {
    /// Adds the element if it's missing, removes it if it's present.
    mutating func toggle(_ element: Element) {
        if contains(element) { remove(element) } else { insert(element) }
    }
}

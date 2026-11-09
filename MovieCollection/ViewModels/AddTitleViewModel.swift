//
//  AddTitleViewModel.swift
//  MovieCollection
//
//  Purpose: The "Type it in" form. Typing a title suggests catalog matches;
//  picking one fills in every field, and everything stays editable so
//  titles not in the catalog can be entered by hand.
//  Used in: AddTitleView.
//

import Foundation
import Observation
import SwiftData

@Observable
final class AddTitleViewModel {
    var title = ""
    var kind: TitleKind = .movie {
        didSet {
            // Movie and TV ratings differ (PG-13 vs TV-14), so clear one that no longer applies.
            if let filmRating, !kind.ratingOptions.contains(filmRating) { self.filmRating = nil }
        }
    }
    var yearText = ""
    var runtimeText = ""
    var director = ""
    /// Comma-separated names.
    var castText = ""
    /// Comma-separated genres.
    var genresText = ""
    var filmRating: FilmRating?
    var format: MediaFormat = .dvd {
        didSet {
            if let service, !format.allowedServices.contains(service) { self.service = nil }
        }
    }
    /// Where a new disc goes. Nil means the Shelf.
    var location: StorageLocation?
    var loanedTo = ""
    var loanedOn = Date.now
    var dueBack: Date?
    var tags: [Tag] = []
    var service: StreamingService?
    var hasWatched = false
    var lastWatched = Date.now

    /// The catalog movie the fields were filled from, if any.
    private(set) var pickedMovie: Movie?

    private let appModel: AppViewModel

    var locationOptions: [StorageLocation] { appModel.locations }

    init(appModel: AppViewModel) {
        self.appModel = appModel
    }

    // MARK: - Suggestions

    /// TMDB results for the typed title, filled in by `searchOnline()`.
    private(set) var onlineResults: [Movie] = []
    /// True while a TMDB movie's director, cast, and rating are being fetched.
    private(set) var isLoadingDetails = false

    /// Bundled catalog matches for the typed title (instant), then TMDB
    /// matches not already listed. Hidden once one has been picked.
    var suggestions: [Movie] {
        guard title.trimmed.count >= 2, pickedMovie?.title != title else { return [] }
        let local = appModel.catalogMatches(for: title)
        let localIDs = Set(local.map(\.id))
        return local + onlineResults.filter { !localIDs.contains($0.id) }.prefix(5)
    }

    /// Searches TMDB for the typed title after a short pause in typing.
    /// The view restarts this on every keystroke, which cancels the last search.
    func searchOnline() async {
        onlineResults = []
        let query = title.trimmed
        guard appModel.hasOnlineCatalog, query.count >= 2, pickedMovie?.title != title else { return }
        do {
            try await Task.sleep(for: .milliseconds(350))
        } catch {
            return
        }
        let results = await appModel.searchMovies(query)
        guard !Task.isCancelled, query == title.trimmed else { return }
        onlineResults = results
    }

    /// Fills the form from a suggestion, then fetches the rest of a TMDB
    /// result's details (director, cast, runtime, film rating).
    func choose(_ movie: Movie) async {
        pick(movie)
        await completePickedDetails()
    }

    /// Fetches full details if the picked movie is a TMDB search result.
    func completePickedDetails() async {
        guard let summary = pickedMovie, summary.isSummary else { return }
        isLoadingDetails = true
        defer { isLoadingDetails = false }
        let full = await appModel.fullDetails(for: summary)
        // Skip it if the user has picked something else or retyped the title meanwhile.
        guard !full.isSummary, pickedMovie?.id == summary.id, title == summary.title else { return }
        pick(full)
    }

    /// Fills every field from a catalog movie.
    func pick(_ movie: Movie) {
        pickedMovie = movie
        title = movie.title
        kind = .movie
        yearText = movie.year.map(String.init) ?? ""
        runtimeText = movie.runtime.map(String.init) ?? ""
        director = movie.director
        castText = movie.cast.joined(separator: ", ")
        genresText = movie.genres.joined(separator: ", ")
        filmRating = movie.filmRating
    }

    /// The picked movie, but only while the title still matches it.
    /// Editing the title by hand turns it into a hand-entered title.
    private var linkedMovie: Movie? {
        guard let pickedMovie, pickedMovie.title == title else { return nil }
        return pickedMovie
    }

    var isAlreadyOnShelf: Bool {
        guard let linkedMovie else { return false }
        return appModel.isOnShelf(catalogID: linkedMovie.id)
    }

    // MARK: - Validation

    private var year: Int? { Int(yearText.trimmed) }
    private var runtime: Int? { Int(runtimeText.trimmed) }

    var yearIsValid: Bool {
        yearText.trimmed.isEmpty || (year.map { (1870...2100).contains($0) } ?? false)
    }

    var runtimeIsValid: Bool {
        runtimeText.trimmed.isEmpty || (runtime.map { $0 > 0 && $0 < 1000 } ?? false)
    }

    var needsService: Bool { format.needsService && service == nil }

    var canSave: Bool {
        !title.trimmed.isEmpty && yearIsValid && runtimeIsValid && !needsService
    }

    // MARK: - Saving

    /// Adds the title to the shelf and returns its ID, or nil if it couldn't be saved.
    func save() -> PersistentIdentifier? {
        guard canSave else { return nil }
        let newTitle = OwnedTitle(
            catalogID: linkedMovie?.id,
            title: title.trimmed,
            kind: kind,
            genres: Self.list(genresText),
            overview: linkedMovie?.overview ?? "",
            year: year,
            runtime: runtime,
            director: director.trimmed,
            cast: Self.list(castText),
            filmRating: filmRating,
            imdbID: linkedMovie?.imdbID,
            format: format,
            service: service,
            lastWatched: hasWatched ? lastWatched : nil
        )
        guard appModel.add(newTitle) else { return nil }
        // Saved on the Shelf by default; move it if somewhere else was picked.
        if format.isPhysical, let location, location !== newTitle.storageLocation {
            appModel.move(
                newTitle, to: location, loanedTo: location.role == .loanedOut ? loanedTo : nil,
                on: loanedOn, dueBack: dueBack)
        }
        if !tags.isEmpty { appModel.setTags(tags, on: newTitle) }
        return newTitle.persistentModelID
    }

    private static func list(_ text: String) -> [String] {
        text.split(separator: ",").map { String($0).trimmed }.filter { !$0.isEmpty }
    }
}

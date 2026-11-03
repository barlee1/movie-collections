//
//  CoverScanViewModel.swift
//  MovieCollection
//
//  Purpose: Reads the title off a DVD or Blu-ray case (live from the camera, or
//  from a photo) and suggests the matching catalog movies, searching TMDB
//  when the bundled catalog has no match. Text recognition itself runs on
//  the phone with Apple's Vision framework; only the read text is searched.
//  Used in: ScanCoverView.
//

import Foundation
import Observation
import Vision

@Observable
final class CoverScanViewModel {
    /// The text lines read from the cover, top to bottom.
    private(set) var recognizedLines: [String] = []
    /// Best catalog matches for the recognized text, best first.
    private(set) var matches: [Movie] = []
    private(set) var isReading = false
    /// True once something has been read, so "no match" can be shown.
    private(set) var hasScanned = false
    var errorMessage: String?

    private let appModel: AppViewModel

    init(appModel: AppViewModel) {
        self.appModel = appModel
    }

    /// The pending TMDB lookup for live camera text, replaced as the text changes.
    @ObservationIgnored private var onlineSearch: Task<Void, Never>?

    /// Text arriving continuously from the live camera scanner.
    func updateLiveText(_ lines: [String]) {
        guard lines != recognizedLines else { return }
        recognizedLines = lines
        hasScanned = !lines.isEmpty
        // Keep the last good matches while the camera briefly loses the text.
        let newMatches = CoverMatcher.rankMovies(for: lines, in: appModel.catalog)
        if !newMatches.isEmpty {
            onlineSearch?.cancel()
            matches = newMatches
        } else if appModel.hasOnlineCatalog, !lines.isEmpty {
            // Wait for the camera to settle on the text before asking TMDB.
            onlineSearch?.cancel()
            onlineSearch = Task {
                try? await Task.sleep(for: .milliseconds(800))
                guard !Task.isCancelled else { return }
                let online = await onlineMatches(for: lines)
                guard !Task.isCancelled, lines == recognizedLines, !online.isEmpty else { return }
                matches = online
            }
        }
    }

    /// Reads a photo of a cover (any image format Vision understands).
    func read(imageData: Data) async {
        isReading = true
        defer { isReading = false }
        do {
            let lines = try await CoverTextReader.lines(in: imageData)
            recognizedLines = lines
            matches = CoverMatcher.rankMovies(for: lines, in: appModel.catalog)
            if matches.isEmpty {
                matches = await onlineMatches(for: lines)
            }
            hasScanned = true
        } catch {
            errorMessage = "Couldn't read that photo: \(error.localizedDescription)"
        }
    }

    /// How many lines of cover text to search TMDB with. Titles are usually
    /// near the top; the rest tends to be taglines and credits.
    static let onlineSearchLineLimit = 3

    /// TMDB movies matching the cover text, ranked the same way as bundled matches.
    private func onlineMatches(for lines: [String]) async -> [Movie] {
        guard appModel.hasOnlineCatalog else { return [] }
        let queries = lines.filter { $0.filter(\.isLetter).count >= 3 }.prefix(Self.onlineSearchLineLimit)
        var candidates: [Movie] = []
        for query in queries {
            for movie in await appModel.searchMovies(query) where !candidates.contains(where: { $0.id == movie.id }) {
                candidates.append(movie)
            }
        }
        return CoverMatcher.rankMovies(for: lines, in: candidates)
    }

    func isOnShelf(_ movie: Movie) -> Bool {
        appModel.isOnShelf(catalogID: movie.id)
    }

    func reset() {
        onlineSearch?.cancel()
        recognizedLines = []
        matches = []
        hasScanned = false
    }
}

/// On-device text recognition with Vision.
nonisolated enum CoverTextReader {
    /// The lines of text in an image, in reading order.
    @concurrent
    static func lines(in imageData: Data) async throws -> [String] {
        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        // Titles are often stylized; language correction helps read them as words.
        request.usesLanguageCorrection = true
        let observations = try await request.perform(on: imageData)
        return observations.map(\.transcript).filter { !$0.trimmed.isEmpty }
    }
}

//
//  TitleDeckViewModel.swift
//  MovieCollection
//
//  Purpose: State for the flip-card viewer: which title is centered, which
//  card is flipped to its details, and next/previous navigation.
//  Used in: TitleDeckView.
//

import Foundation
import Observation
import SwiftData

@Observable
final class TitleDeckViewModel {

    /// The centered card. Bound to the scroll position, so swiping updates it too.
    var currentID: PersistentIdentifier? {
        didSet {
            // Moving to another card turns the previous one back to its poster.
            if currentID != oldValue { flippedID = nil }
        }
    }

    /// The card currently showing its details side, if any.
    private(set) var flippedID: PersistentIdentifier?

    let appModel: AppViewModel
    private let ids: [PersistentIdentifier]

    init(ids: [PersistentIdentifier], startID: PersistentIdentifier, appModel: AppViewModel) {
        self.ids = ids
        self.appModel = appModel
        self.currentID = startID
    }

    // MARK: - Cards

    /// The deck's titles, in order. Titles removed from the shelf drop out.
    var titles: [OwnedTitle] {
        ids.compactMap(appModel.title(with:))
    }

    var currentTitle: OwnedTitle? {
        currentID.flatMap(appModel.title(with:))
    }

    private var currentIndex: Int? {
        titles.firstIndex { $0.persistentModelID == currentID }
    }

    /// e.g. "4 of 30"
    var positionLabel: String {
        guard let currentIndex else { return "" }
        return "\(currentIndex + 1) of \(titles.count)"
    }

    func isFlipped(_ title: OwnedTitle) -> Bool {
        flippedID == title.persistentModelID
    }

    var isCurrentFlipped: Bool {
        flippedID != nil && flippedID == currentID
    }

    // MARK: - Actions

    /// Tapping the centered card flips it; tapping a peeking neighbor moves to it.
    func tap(_ title: OwnedTitle) {
        let id = title.persistentModelID
        if id == currentID {
            flippedID = (flippedID == id) ? nil : id
        } else {
            currentID = id
        }
    }

    var canGoPrevious: Bool { (currentIndex ?? 0) > 0 }
    var canGoNext: Bool { (currentIndex ?? titles.count) < titles.count - 1 }

    func goPrevious() {
        guard let currentIndex, currentIndex > 0 else { return }
        currentID = titles[currentIndex - 1].persistentModelID
    }

    func goNext() {
        guard let currentIndex, currentIndex < titles.count - 1 else { return }
        currentID = titles[currentIndex + 1].persistentModelID
    }

    /// If the centered title was removed (for example from its full details),
    /// moves to the nearest remaining card.
    func recoverIfCurrentRemoved() {
        guard currentIndex == nil, let first = titles.first else { return }
        currentID = first.persistentModelID
    }
}

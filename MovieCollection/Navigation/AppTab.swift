//
//  AppTab.swift
//  MovieCollection
//
//  Purpose: The five tabs in the bottom bar, with their labels and icons.
//  Used in: navBar, AppRouter, RootTabView.
//

import Foundation

enum AppTab: String, CaseIterable, Identifiable, Hashable {
    case shelf
    case tonight
    case add
    case reviews
    case profile

    var id: String { rawValue }

    var label: String {
        switch self {
        case .shelf: "Shelf"
        case .tonight: "Tonight"
        case .add: "Add"
        case .reviews: "Reviews"
        case .profile: "Profile"
        }
    }

    /// SF Symbols chosen to match the design's Lucide icons.
    var systemImage: String {
        switch self {
        case .shelf: "books.vertical"
        case .tonight: "play.circle"
        case .add: "plus"
        case .reviews: "text.bubble"
        case .profile: "person.crop.circle"
        }
    }
}

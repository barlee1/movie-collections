//
//  PreviewSupport.swift
//  MovieCollection
//
//  Purpose: Builds an AppViewModel backed by an in-memory store for SwiftUI
//  previews, so previews never touch the real saved shelf.
//  Used in: #Preview blocks.
//

import Foundation
import SwiftData

extension AppViewModel {
    /// A view model with its own throwaway store and settings, set up as the
    /// sample user with the sample shelf once started. Call `await start()`
    /// (or use the `.task` in a preview) to load it.
    /// - Parameter asGuest: True starts as a first-launch guest instead, to
    ///   preview the "Make it yours" prompts and profile setup.
    static func preview(asGuest: Bool = false) -> AppViewModel {
        let container: ModelContainer
        do {
            container = try CollectionStore.makeContainer(inMemory: true)
        } catch {
            fatalError("Could not create the preview store: \(error)")
        }
        // A separate defaults suite so previews never change the real app's profile.
        let defaults = UserDefaults(suiteName: "MovieCollectionPreview-\(UUID().uuidString)") ?? .standard
        let appModel = AppViewModel(store: CollectionStore(container: container), settings: defaults)
        if !asGuest {
            appModel.setProfile(.sample)
            appModel.loadsSampleShelfOnStart = true
        }
        return appModel
    }
}

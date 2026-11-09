//
//  MovieCollectionApp.swift
//  MovieCollection
//
//  Created by Kylee Brown on 9/24/26.
//

import SwiftData
import SwiftUI

@main
struct MovieCollectionApp: App {
    private let container: ModelContainer
    @State private var appModel: AppViewModel

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        // UI tests launch with "-UITesting" to get a fresh, throwaway shelf every run,
        // so they never change the real saved data. On its own that starts as a
        // brand-new guest; adding "-SampleShelf" starts as the set-up sample
        // user (Ella) with the 30 sample titles instead.
        let isUITesting = arguments.contains("-UITesting")
        let startsWithSampleShelf = isUITesting && arguments.contains("-SampleShelf")

        // The app can't work without its on-device store, so failing here is fatal.
        let container: ModelContainer
        do {
            container = try CollectionStore.makeContainer(inMemory: isUITesting)
        } catch {
            fatalError("Could not create the collection store: \(error)")
        }
        self.container = container

        let settings =
            isUITesting
            ? UserDefaults(suiteName: "MovieCollectionUITesting-\(UUID().uuidString)") ?? .standard
            : .standard
        let appModel = AppViewModel(
            store: CollectionStore(container: container),
            // UI tests stay offline so their search results never change.
            remoteCatalog: isUITesting ? nil : TMDBClient.fromBundle(),
            settings: settings,
            // UI tests never schedule real notifications.
            loanReminders: isUITesting ? NoLoanReminders() : SystemLoanReminders()
        )
        if startsWithSampleShelf {
            appModel.setProfile(.sample)
            appModel.loadsSampleShelfOnStart = true
        }
        _appModel = State(initialValue: appModel)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appModel)
                .task { await appModel.start() }
        }
        .modelContainer(container)
    }
}

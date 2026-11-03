//
//  SubscriptionTests.swift
//  MovieCollectionTests
//
//  Purpose: The user's saved profile: starting as a guest with an empty shelf,
//  signing in, editing name, photo, and streaming services, surviving a
//  relaunch, and feeding the shelf's service filter.
//

import Foundation
import SwiftData
import Testing
import UIKit

@testable import MovieCollection

@Suite("Profile and guest mode")
@MainActor
struct ProfileTests {

    /// An app model that hasn't signed in, sharing `settings` so a
    /// second one acts like a relaunch.
    private func makeAppModel(settings: UserDefaults) throws -> AppViewModel {
        AppViewModel(
            store: CollectionStore(container: try CollectionStore.makeContainer(inMemory: true)),
            settings: settings
        )
    }

    @Test("A first launch starts as a guest with an empty shelf, no sign-in needed")
    func firstLaunchIsGuest() async throws {
        let appModel = try makeAppModel(settings: try TestSupport.freshDefaults())
        await appModel.start()
        #expect(appModel.isGuest)
        #expect(appModel.profile?.name == "Guest")
        #expect(appModel.subscriptions.isEmpty)
        #expect(appModel.titles.isEmpty, "Nothing is added for them")
        #expect(!appModel.hasSampleTitles)
    }

    @Test("A guest's own titles are saved across relaunches")
    func guestChangesPersist() async throws {
        let settings = try TestSupport.freshDefaults()
        let container = try CollectionStore.makeContainer(inMemory: true)
        let first = AppViewModel(store: CollectionStore(container: container), settings: settings)
        await first.start()
        first.add(OwnedTitle(title: "Guest Pick", format: .dvd))
        first.setSubscriptions([.hulu])

        let relaunched = AppViewModel(store: CollectionStore(container: container), settings: settings)
        await relaunched.start()
        #expect(relaunched.isGuest)
        #expect(relaunched.titles.map(\.title) == ["Guest Pick"])
        #expect(relaunched.subscriptions == [.hulu])
    }

    @Test("A shelf left by an early build is kept")
    func earlyBuildShelfKept() async throws {
        let container = try CollectionStore.makeContainer(inMemory: true)
        let store = CollectionStore(container: container)
        try store.add(OwnedTitle(title: "From Before", format: .dvd))
        let appModel = AppViewModel(store: store, settings: try TestSupport.freshDefaults())
        await appModel.start()
        #expect(appModel.titles.map(\.title) == ["From Before"])
        #expect(appModel.isGuest)
    }

    @Test("Signing in keeps the guest's titles, and comes back after a relaunch")
    func setupPersists() async throws {
        let settings = try TestSupport.freshDefaults()
        let first = try makeAppModel(settings: settings)
        await first.start()
        first.add(OwnedTitle(title: "Tried It Out", format: .dvd))
        first.finishSetup(
            with: UserProfile(name: "  Sam Rivera ", subscriptions: [.hulu, .netflix], isGuest: true),
            keepingSampleShelf: true
        )
        #expect(!first.isGuest, "Signing in always ends guest mode")
        #expect(first.titles.map(\.title) == ["Tried It Out"])

        let relaunched = try makeAppModel(settings: settings)
        #expect(!relaunched.isGuest)
        #expect(relaunched.profile?.name == "Sam Rivera", "Names are trimmed")
        #expect(relaunched.subscriptions == [.netflix, .hulu], "Services are kept in the usual order")
    }

    @Test("Starting fresh removes only the sample movies")
    func startFresh() async throws {
        let appModel = try makeAppModel(settings: try TestSupport.freshDefaults())
        await appModel.start()
        appModel.loadSampleShelf()
        appModel.add(OwnedTitle(title: "Mine", format: .dvd))
        appModel.finishSetup(with: UserProfile(name: "Sam"), keepingSampleShelf: false)
        #expect(appModel.titles.map(\.title) == ["Mine"])
        #expect(!appModel.hasSampleTitles)
        #expect(try appModel.store.allReviews().isEmpty, "The sample reviews go with their titles")
    }

    @Test("Profiles saved before guest mode load as set up")
    func olderProfileDecodes() throws {
        let json = #"{"name":"Ella","subscriptions":["Netflix"]}"#
        let profile = try JSONDecoder().decode(UserProfile.self, from: Data(json.utf8))
        #expect(!profile.isGuest)
        #expect(profile.subscriptions == [.netflix])
    }

    @Test("Saved services come back after a relaunch, in the usual order")
    func subscriptionsPersist() throws {
        let settings = try TestSupport.freshDefaults()
        let first = try makeAppModel(settings: settings)
        first.setProfile(.sample)
        first.setSubscriptions([.hulu, .netflix, .disneyPlus])
        #expect(first.subscriptions == [.netflix, .hulu, .disneyPlus])

        let relaunched = try makeAppModel(settings: settings)
        #expect(relaunched.subscriptions == [.netflix, .hulu, .disneyPlus])
    }

    @Test("Removing every service is remembered too")
    func emptyPersists() throws {
        let settings = try TestSupport.freshDefaults()
        let first = try makeAppModel(settings: settings)
        first.setProfile(.sample)
        first.setSubscriptions([])
        #expect(try makeAppModel(settings: settings).subscriptions.isEmpty)
    }

    @Test("Editing the name and photo keeps the services")
    func editProfile() throws {
        let settings = try TestSupport.freshDefaults()
        let appModel = try makeAppModel(settings: settings)
        appModel.setProfile(.sample)

        var edited = try #require(appModel.profile)
        edited.name = "Ella L."
        edited.photoAssetName = nil
        edited.photoData = Data([1, 2, 3])
        edited.subscriptions = []
        appModel.updateProfile(edited)

        let saved = try #require(try makeAppModel(settings: settings).profile)
        #expect(saved.name == "Ella L.")
        #expect(saved.photoAssetName == nil, "Removing the sample photo sticks")
        #expect(saved.photoData == Data([1, 2, 3]))
        #expect(saved.subscriptions == [.amazonPrime, .netflix], "Subscriptions are edited separately")
    }

    @Test("A blank name is never saved over the real one")
    func blankNameIgnored() throws {
        let appModel = try makeAppModel(settings: try TestSupport.freshDefaults())
        appModel.setProfile(.sample)
        appModel.updateProfile(UserProfile(name: "   "))
        #expect(appModel.profile?.name == "Ella Lauren")
    }

    @Test("Services saved by an early build are preselected in sign-in")
    func legacySubscriptions() throws {
        let settings = try TestSupport.freshDefaults()
        settings.set(["Hulu", "Max"], forKey: AppViewModel.legacySubscriptionsKey)
        let appModel = try makeAppModel(settings: settings)
        #expect(SignInViewModel(appModel: appModel).subscriptions == [.hulu, .max])
    }

    @Test("The shelf's service filter offers the edited services")
    func shelfFilter() async throws {
        let appModel = try await TestSupport.makeAppModel(seeded: false)
        let shelf = ShelfViewModel(appModel: appModel)
        #expect(shelf.serviceOptions == [.amazonPrime, .netflix])

        appModel.setSubscriptions([.max, .peacock])
        #expect(shelf.serviceOptions == [.max, .peacock])
    }

    @Test(
        "Initials for the placeholder avatar",
        arguments: [
            ("Ella Lauren", "EL"), ("cher", "C"), ("Mary Jane Watson", "MJ"), ("  ", "?"),
        ])
    func initials(name: String, expected: String) {
        #expect(UserProfile(name: name).initials == expected)
    }

    @Test("Picked photos are cropped square and shrunk for saving")
    func photoIsShrunk() throws {
        let big = UIGraphicsImageRenderer(size: CGSize(width: 1200, height: 800)).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1200, height: 800))
        }
        let data = try #require(big.pngData())
        let prepared = try #require(ProfilePhoto.prepared(from: data))
        let image = try #require(UIImage(data: prepared))
        #expect(image.size.width == ProfilePhoto.maxDimension)
        #expect(image.size.height == ProfilePhoto.maxDimension)
        #expect(prepared.count < data.count)
        #expect(ProfilePhoto.prepared(from: Data("not a photo".utf8)) == nil)
    }
}

@Suite("Sign-in steps")
@MainActor
struct SignInTests {

    /// A first-launch guest with an empty shelf.
    private func makeGuest() async throws -> AppViewModel {
        let appModel = AppViewModel(
            store: CollectionStore(container: try CollectionStore.makeContainer(inMemory: true)),
            settings: try TestSupport.freshDefaults()
        )
        await appModel.start()
        return appModel
    }

    @Test("Needs a name, then services, then signs in keeping the guest's titles")
    func steps() async throws {
        let appModel = try await makeGuest()
        appModel.add(OwnedTitle(title: "Added Before Signing In", format: .dvd))
        let signIn = SignInViewModel(appModel: appModel)
        #expect(signIn.steps == [.aboutYou, .services], "No sample question without sample movies")
        #expect(signIn.step == .aboutYou)
        #expect(!signIn.canContinue)

        signIn.next()
        #expect(signIn.step == .aboutYou, "Can't skip the name")

        signIn.name = "Sam"
        signIn.next()
        #expect(signIn.step == .services)
        #expect(signIn.progressLabel == "Step 2 of 2")
        #expect(signIn.isLastStep)
        signIn.subscriptions = [.peacock]

        signIn.back()
        #expect(signIn.step == .aboutYou)
        signIn.next()

        signIn.signIn()
        #expect(!appModel.isGuest)
        #expect(appModel.profile?.name == "Sam")
        #expect(appModel.subscriptions == [.peacock])
        #expect(appModel.titles.map(\.title) == ["Added Before Signing In"])
    }

    @Test("With the sample movies loaded, a last step asks whether to keep them")
    func sampleStep() async throws {
        let appModel = try await makeGuest()
        appModel.loadSampleShelf()
        appModel.add(OwnedTitle(title: "Mine", format: .dvd))
        let signIn = SignInViewModel(appModel: appModel)
        #expect(signIn.steps == [.aboutYou, .services, .shelf])
        signIn.name = "Sam"
        signIn.next()
        #expect(!signIn.isLastStep)
        signIn.next()
        #expect(signIn.step == .shelf)

        signIn.signIn(keepingSampleShelf: false)
        #expect(!appModel.isGuest)
        #expect(appModel.titles.map(\.title) == ["Mine"])
    }

    @Test("Leaving sign-in unfinished keeps the user a guest")
    func notFinished() async throws {
        let appModel = try await makeGuest()
        let signIn = SignInViewModel(appModel: appModel)
        signIn.name = "Sam"
        signIn.next()
        #expect(appModel.isGuest, "Nothing is saved until the last step")
        #expect(appModel.profile?.name == "Guest")
    }
}

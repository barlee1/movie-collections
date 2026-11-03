//
//  UserProfile.swift
//  MovieCollection
//
//  Purpose: The person using the app. New users start as a guest with an
//  empty shelf and sign in whenever they're ready. There's no account server
//  yet, so the profile is saved only on the phone.
//  Used in: AppViewModel, onboarding, Profile screen.
//

import Foundation

nonisolated struct UserProfile: Codable, Hashable, Sendable {
    var name: String
    /// A small JPEG of the user's chosen photo, if they picked one.
    var photoData: Data?
    /// An asset catalog image, used only by the sample profile in previews and UI tests.
    var photoAssetName: String?
    /// The streaming services the user pays for, in the app's usual service order.
    var subscriptions: [StreamingService]
    /// True while someone is just exploring the app and hasn't set up their profile.
    var isGuest: Bool

    init(
        name: String,
        photoData: Data? = nil,
        photoAssetName: String? = nil,
        subscriptions: [StreamingService] = [],
        isGuest: Bool = false
    ) {
        self.name = name
        self.photoData = photoData
        self.photoAssetName = photoAssetName
        self.subscriptions = subscriptions
        self.isGuest = isGuest
    }

    private enum CodingKeys: String, CodingKey {
        case name, photoData, photoAssetName, subscriptions, isGuest
    }

    /// Profiles saved before guest mode existed have no `isGuest`; they were set up by hand.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        photoData = try container.decodeIfPresent(Data.self, forKey: .photoData)
        photoAssetName = try container.decodeIfPresent(String.self, forKey: .photoAssetName)
        subscriptions = try container.decode([StreamingService].self, forKey: .subscriptions)
        isGuest = try container.decodeIfPresent(Bool.self, forKey: .isGuest) ?? false
    }

    /// Up to two initials for the placeholder avatar, e.g. "EL".
    var initials: String {
        let letters = name.split(separator: " ").prefix(2).compactMap(\.first)
        return letters.isEmpty ? "?" : String(letters).uppercased()
    }

    /// Who's using the app before signing in: no name, photo, or services yet.
    static let guest = UserProfile(name: "Guest", isGuest: true)

    /// The design's sample user, for previews, tests, and UI tests.
    static let sample = UserProfile(
        name: "Ella Lauren",
        photoAssetName: "EllaProfile",
        subscriptions: [.amazonPrime, .netflix]
    )
}

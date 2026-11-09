//
//  AppViewModel+Family.swift
//  MovieCollection
//
//  Purpose: The app-wide actions for family members, who has seen what, and
//  family ratings. Each one saves through CollectionStore and refreshes the
//  shelf, so every screen updates; a failure shows the usual error alert.
//  Used in: Settings › Family, the detail screen, the watch sheet.
//

import Foundation

extension AppViewModel {

    // MARK: - Members

    var hasFamily: Bool { !familyMembers.isEmpty }

    /// The user's profile, when it's listed alongside the family: they're
    /// signed in, have added family, and haven't turned it off in Settings › Family.
    /// What "you" have seen and rated comes from your own watches and reviews.
    var familyYou: UserProfile? {
        guard hasFamily, includesYouInFamily, let profile, !profile.isGuest else { return nil }
        return profile
    }

    /// Whether another member can be added.
    var canAddFamilyMember: Bool { familyMembers.count < FamilyMember.limit }

    /// The next avatar color, so new members don't all look the same.
    var nextFamilyColorIndex: Int { familyMembers.count % TagPalette.count }

    @discardableResult
    func addFamilyMember(named name: String, age: Int?, colorIndex: Int) -> FamilyMember? {
        let cleaned = name.cleanedTagName
        guard !cleaned.isEmpty else { return nil }
        var added: FamilyMember?
        _ = perform("add \(cleaned)") {
            added = try store.addFamilyMember(named: cleaned, age: age, colorIndex: colorIndex)
        }
        return added
    }

    @discardableResult
    func updateFamilyMember(_ member: FamilyMember, name: String, age: Int?, colorIndex: Int) -> Bool {
        let cleaned = name.cleanedTagName
        guard !cleaned.isEmpty else { return false }
        return perform("save \(cleaned)") {
            try store.updateFamilyMember(member, name: cleaned, age: age, colorIndex: colorIndex)
        }
    }

    @discardableResult
    func reorderFamilyMembers(_ ordered: [FamilyMember]) -> Bool {
        perform("reorder your family") { try store.reorderFamilyMembers(ordered) }
    }

    @discardableResult
    func deleteFamilyMember(_ member: FamilyMember) -> Bool {
        perform("remove \(member.name)") { try store.deleteFamilyMember(member) }
    }

    // MARK: - Seen and ratings

    @discardableResult
    func setSeen(_ seen: Bool, by member: FamilyMember, title: OwnedTitle) -> Bool {
        perform("save what \(member.name) has seen") { try store.setSeen(seen, by: member, title: title) }
    }

    @discardableResult
    func setFamilyRating(_ rating: Double?, by member: FamilyMember, title: OwnedTitle) -> Bool {
        perform("save \(member.name)'s rating") { try store.setFamilyRating(rating, by: member, title: title) }
    }

    /// Family members who haven't seen a title, in the user's order.
    func familyMembers(notSeen title: OwnedTitle) -> [FamilyMember] {
        familyMembers.filter { !title.hasBeenSeen(by: $0) }
    }

    /// Names of everyone who hasn't seen a title: the user first (if listed), then family.
    func names(notSeen title: OwnedTitle) -> [String] {
        let you = familyYou.flatMap { title.isWatched ? nil : $0.name }
        return [you].compactMap { $0 } + familyMembers(notSeen: title).map(\.name)
    }
}

//
//  CollectionStore+Family.swift
//  MovieCollection
//
//  Purpose: Reading and writing family members, who has seen each title,
//  and their own ratings. Enforces the limit of 15 members.
//  Used in: AppViewModel+Family.
//

import Foundation
import SwiftData

extension CollectionStore {

    enum FamilyError: LocalizedError {
        case full

        var errorDescription: String? {
            switch self {
            case .full: "You can add up to \(FamilyMember.limit) family members."
            }
        }
    }

    // MARK: - Members

    /// Every family member, in the user's order.
    func allFamilyMembers() throws -> [FamilyMember] {
        try context.fetch(FetchDescriptor<FamilyMember>(sortBy: [SortDescriptor(\.sortOrder)]))
    }

    /// Adds a member at the end of the list. Throws `FamilyError.full` past the limit.
    @discardableResult
    func addFamilyMember(named name: String, age: Int?, colorIndex: Int) throws -> FamilyMember {
        let members = try allFamilyMembers()
        guard members.count < FamilyMember.limit else { throw FamilyError.full }
        let member = FamilyMember(
            name: name,
            age: age,
            colorIndex: colorIndex,
            sortOrder: (members.map(\.sortOrder).max() ?? -1) + 1
        )
        context.insert(member)
        try context.save()
        return member
    }

    func updateFamilyMember(_ member: FamilyMember, name: String, age: Int?, colorIndex: Int) throws {
        member.name = name
        member.age = age
        member.colorIndex = colorIndex
        try context.save()
    }

    /// Saves a new order, e.g. after dragging in Settings › Family.
    func reorderFamilyMembers(_ members: [FamilyMember]) throws {
        for (index, member) in members.enumerated() {
            member.sortOrder = index
        }
        try context.save()
    }

    /// Deletes a member, their ratings, and their place in past watches.
    /// The watches themselves stay.
    func deleteFamilyMember(_ member: FamilyMember) throws {
        for watch in member.watches {
            watch.viewers.removeAll { $0.id == member.id }
        }
        context.delete(member)
        try context.save()
    }

    // MARK: - Seen and ratings

    /// Marks a title seen or not seen by a member. Not seen also removes
    /// their rating and takes them off the title's watches.
    func setSeen(_ seen: Bool, by member: FamilyMember, title: OwnedTitle) throws {
        if seen {
            if let record = title.familyRecord(for: member) {
                record.markedSeen = true
            } else {
                insertRecord(FamilyRating(markedSeen: true), member: member, title: title)
            }
        } else {
            if let record = title.familyRecord(for: member) {
                title.familyRatings.removeAll { $0 === record }
                context.delete(record)
            }
            for watch in title.watches(seenBy: member) {
                watch.viewers.removeAll { $0.id == member.id }
            }
        }
        try context.save()
    }

    /// Sets or clears a member's stars. Rating a title also counts as seeing it.
    func setFamilyRating(_ rating: Double?, by member: FamilyMember, title: OwnedTitle) throws {
        if let record = title.familyRecord(for: member) {
            record.rating = rating.map(Review.normalized)
            if rating != nil { record.markedSeen = true }
        } else if let rating {
            insertRecord(FamilyRating(rating: rating, markedSeen: true), member: member, title: title)
        }
        try context.save()
    }

    private func insertRecord(_ record: FamilyRating, member: FamilyMember, title: OwnedTitle) {
        context.insert(record)
        record.member = member
        title.familyRatings.append(record)
    }
}

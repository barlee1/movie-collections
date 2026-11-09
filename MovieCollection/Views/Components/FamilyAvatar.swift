//
//  FamilyAvatar.swift
//  MovieCollection
//
//  Purpose: A family member's colored circle with their initial, and a
//  toggleable chip with the circle and name for picking who's watching.
//  The chip also works for the user's own profile (their photo and name).
//  Used in: Settings › Family, the detail screen's Family section, the watch
//  sheet, the Shelf filter sheet, Tonight.
//

import SwiftUI

/// A colored circle with a family member's initial.
struct FamilyAvatar: View {
    let initial: String
    let colorIndex: Int
    var size: CGFloat = 36

    init(member: FamilyMember, size: CGFloat = 36) {
        self.initial = member.initial
        self.colorIndex = member.colorIndex
        self.size = size
    }

    init(initial: String, colorIndex: Int, size: CGFloat = 36) {
        self.initial = initial
        self.colorIndex = colorIndex
        self.size = size
    }

    @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1

    var body: some View {
        let colors = TagPalette.colors(colorIndex)
        Text(initial)
            .font(Theme.Fonts.heading(size * 0.45 * scale, relativeTo: .body))
            .foregroundStyle(colors.text)
            .frame(width: size * scale, height: size * scale)
            .background(colors.fill, in: Circle())
            .overlay(Circle().strokeBorder(Theme.Colors.divider))
            .accessibilityHidden(true)
    }
}

/// A family member, or the user themselves, that you can tap on or off,
/// e.g. in "Who's watching?".
struct FamilyMemberChip: View {
    private enum Person {
        case member(FamilyMember)
        case you(UserProfile)
    }

    private let person: Person
    let isOn: Bool
    let action: () -> Void

    init(member: FamilyMember, isOn: Bool, action: @escaping () -> Void) {
        self.person = .member(member)
        self.isOn = isOn
        self.action = action
    }

    /// The user, shown with their profile photo and name.
    init(you profile: UserProfile, isOn: Bool, action: @escaping () -> Void) {
        self.person = .you(profile)
        self.isOn = isOn
        self.action = action
    }

    private var name: String {
        switch person {
        case .member(let member): member.name
        case .you(let profile): profile.name
        }
    }

    @ViewBuilder
    private var avatar: some View {
        switch person {
        case .member(let member):
            FamilyAvatar(member: member, size: 24)
        case .you(let profile):
            // ProfileAvatar adds a ring of 6% on each side; keep the chip the same height.
            ProfileAvatar(profile: profile, size: 24 / 1.12)
                .accessibilityHidden(true)
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                avatar
                Text(name)
                    .font(Theme.Fonts.body(14, weight: .semibold, relativeTo: .subheadline))
                    .lineLimit(1)
                if isOn {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .accessibilityHidden(true)
                }
            }
            .padding(.leading, 5)
            .padding(.trailing, 12)
            .padding(.vertical, 5)
            .foregroundStyle(isOn ? Theme.Colors.onAction : Theme.Colors.text)
            .background(isOn ? Theme.Colors.action : Theme.Colors.surface, in: Capsule())
            .overlay(Capsule().strokeBorder(isOn ? Color.clear : Theme.Colors.divider))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(name)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

#Preview {
    HStack {
        FamilyAvatar(initial: "S", colorIndex: 0)
        FamilyAvatar(initial: "R", colorIndex: 2)
        FamilyAvatar(initial: "M", colorIndex: 4, size: 24)
    }
    .padding()
}

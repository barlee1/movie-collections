//
//  ManageFamilyView.swift
//  MovieCollection
//
//  Purpose: Settings › Family: up to 15 people the user watches with. Add
//  one, tap to edit their name, age, and color, drag to reorder, swipe to
//  delete (their ratings and place in past watches go too, after a
//  confirmation). Also lists the user by their profile name if they opt in,
//  and turns Tonight's age-based film rating suggestion on or off.
//  Family data stays on this phone only.
//  Used in: RootTabView (Route.manageFamily), opened from Settings.
//

import SwiftUI

struct ManageFamilyView: View {
    @Environment(AppViewModel.self) private var appModel
    /// The member being edited, or a new draft when adding.
    @State private var editing: FamilyEditTarget?
    @State private var deleting: FamilyMember?

    var body: some View {
        @Bindable var appModel = appModel

        List {
            Section {
                Button {
                    editing = .new
                } label: {
                    Label("Add a family member", systemImage: "person.badge.plus")
                        .font(Theme.Fonts.body(16, weight: .semibold))
                }
                .disabled(!appModel.canAddFamilyMember)
                .accessibilityIdentifier("family.add")
            } footer: {
                if !appModel.canAddFamilyMember {
                    Text("That's the most: \(FamilyMember.limit) family members.")
                        .font(Theme.Fonts.body(13, relativeTo: .footnote))
                }
            }

            if let profile = appModel.profile, !profile.isGuest, appModel.hasFamily {
                Section {
                    Toggle(isOn: $appModel.includesYouInFamily) {
                        HStack(spacing: 12) {
                            ProfileAvatar(profile: profile, size: 36 / 1.12)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(profile.name)
                                    .font(Theme.Fonts.body(16, weight: .semibold))
                                Text("You")
                                    .font(Theme.Fonts.body(13, relativeTo: .footnote))
                                    .foregroundStyle(Theme.Colors.textMuted)
                            }
                        }
                    }
                    .accessibilityLabel("Include \(profile.name) with the family")
                } footer: {
                    Text("Lists you by your profile name in \"Who's watching?\" and \"Not seen by\". What you've seen and rated comes from your own watches and reviews.")
                        .font(Theme.Fonts.body(13, relativeTo: .footnote))
                }
            }

            Section {
                if appModel.familyMembers.isEmpty {
                    Text("No one yet. Add the people you watch with to see who has seen each movie, keep their own ratings, and find something nobody on the couch has seen.")
                        .font(Theme.Fonts.body(15))
                        .foregroundStyle(Theme.Colors.textMuted)
                }
                ForEach(appModel.familyMembers) { member in
                    Button {
                        editing = .existing(member)
                    } label: {
                        row(member)
                    }
                    .buttonStyle(.plain)
                }
                .onMove(perform: move)
                .onDelete { offsets in
                    deleting = offsets.map { appModel.familyMembers[$0] }.first
                }
            } footer: {
                if !appModel.familyMembers.isEmpty {
                    Text("Tap someone to edit them. Drag to reorder. Family names and ages stay on this phone and are never shared.")
                        .font(Theme.Fonts.body(13, relativeTo: .footnote))
                }
            }

            Section {
                Toggle("Suggest film ratings from ages", isOn: $appModel.suggestsRatingsFromAges)
                    .font(Theme.Fonts.body(16, weight: .semibold))
            } footer: {
                Text("On Tonight, picking who's watching suggests ratings that fit the youngest person: G and PG under 13, up to PG-13 under 17.")
                    .font(Theme.Fonts.body(13, relativeTo: .footnote))
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.Colors.background.ignoresSafeArea())
        .foregroundStyle(Theme.Colors.text)
        .tint(Theme.Colors.action)
        .environment(\.editMode, .constant(appModel.familyMembers.isEmpty ? .inactive : .active))
        .navigationTitle("Family")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editing) { target in
            EditFamilyMemberSheet(target: target) { member in
                deleting = member
            }
        }
        .confirmationDialog(
            "Remove \(deleting?.name ?? "this person")?",
            isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                if let deleting { appModel.deleteFamilyMember(deleting) }
            }
        } message: {
            Text(deleteMessage)
        }
    }

    private func row(_ member: FamilyMember) -> some View {
        HStack(spacing: 12) {
            FamilyAvatar(member: member)
            VStack(alignment: .leading, spacing: 2) {
                Text(member.name)
                    .font(Theme.Fonts.body(16, weight: .semibold))
                if let age = member.age {
                    Text("Age \(age)")
                        .font(Theme.Fonts.body(13, relativeTo: .footnote))
                        .foregroundStyle(Theme.Colors.textMuted)
                }
            }
            Spacer()
            let seen = appModel.titles.filter { $0.hasBeenSeen(by: member) }.count
            Text("Seen \(seen)")
                .font(Theme.Fonts.body(14, relativeTo: .subheadline))
                .foregroundStyle(Theme.Colors.textMuted)
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Edit")
    }

    /// e.g. "Their 4 ratings are deleted, and they come off 12 past watches."
    private var deleteMessage: String {
        guard let deleting else { return "" }
        let ratings = deleting.ratings.filter { $0.rating != nil }.count
        let watches = deleting.watches.count
        var parts: [String] = []
        if ratings > 0 { parts.append("their \(ratings) \(ratings == 1 ? "rating is" : "ratings are") deleted") }
        if watches > 0 { parts.append("they come off \(watches) past \(watches == 1 ? "watch" : "watches")") }
        guard !parts.isEmpty else { return "Nothing else changes." }
        let sentence = parts.joined(separator: ", and ")
        return sentence.prefix(1).uppercased() + sentence.dropFirst() + ". Your own watches and reviews stay."
    }

    private func move(from source: IndexSet, to destination: Int) {
        var ordered = appModel.familyMembers
        ordered.move(fromOffsets: source, toOffset: destination)
        appModel.reorderFamilyMembers(ordered)
    }
}

/// Which member the edit sheet is for.
enum FamilyEditTarget: Identifiable {
    case new
    case existing(FamilyMember)

    var id: String {
        switch self {
        case .new: "new"
        case .existing(let member): member.id.uuidString
        }
    }

    var member: FamilyMember? {
        if case .existing(let member) = self { member } else { nil }
    }
}

/// Add a family member, or edit one's name, age, and color.
private struct EditFamilyMemberSheet: View {
    let target: FamilyEditTarget
    /// Asks the list to confirm removing this member.
    let onDelete: (FamilyMember) -> Void

    @Environment(AppViewModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var ageText: String
    @State private var colorIndex: Int?
    @FocusState private var isNameFocused: Bool

    init(target: FamilyEditTarget, onDelete: @escaping (FamilyMember) -> Void) {
        self.target = target
        self.onDelete = onDelete
        _name = State(initialValue: target.member?.name ?? "")
        _ageText = State(initialValue: target.member?.age.map(String.init) ?? "")
        _colorIndex = State(initialValue: target.member?.colorIndex)
    }

    /// The typed age, or nil if blank. Not a number counts as blank.
    private var age: Int? {
        Int(ageText.trimmed).map { min(max($0, 0), 120) }
    }

    private var chosenColor: Int { colorIndex ?? appModel.nextFamilyColorIndex }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack {
                        Spacer()
                        FamilyAvatar(
                            initial: name.trimmed.first.map { String($0).uppercased() } ?? "?",
                            colorIndex: chosenColor,
                            size: 72
                        )
                        Spacer()
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel(text: "Name", size: 12)
                        TextField("e.g. Sam", text: $name)
                            .textContentType(.givenName)
                            .pillField()
                            .focused($isNameFocused)
                            .accessibilityIdentifier("family.name")
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel(text: "Age (optional)", size: 12)
                        TextField("e.g. 8", text: $ageText)
                            .keyboardType(.numberPad)
                            .pillField()
                            .accessibilityIdentifier("family.age")
                        Text("Used to suggest film ratings on Tonight.")
                            .font(Theme.Fonts.body(13, relativeTo: .footnote))
                            .foregroundStyle(Theme.Colors.textMuted)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        SectionLabel(text: "Color", size: 12)
                        HStack(spacing: 12) {
                            ForEach(0..<TagPalette.count, id: \.self) { index in
                                Button {
                                    colorIndex = index
                                } label: {
                                    Circle()
                                        .fill(TagPalette.colors(index).fill)
                                        .frame(width: 36, height: 36)
                                        .overlay {
                                            if chosenColor == index {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 14, weight: .bold))
                                                    .foregroundStyle(TagPalette.colors(index).text)
                                            }
                                        }
                                        .overlay(Circle().strokeBorder(Theme.Colors.divider))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Color \(index + 1)")
                                .accessibilityAddTraits(chosenColor == index ? .isSelected : [])
                            }
                        }
                    }

                    if let member = target.member {
                        Button("Remove \(member.name)", role: .destructive) {
                            dismiss()
                            onDelete(member)
                        }
                        .font(Theme.Fonts.body(15, weight: .semibold))
                        .foregroundStyle(Theme.Colors.error)
                        .frame(minHeight: 44)
                    }
                }
                .padding(.horizontal, Theme.Spacing.page)
                .padding(.vertical, 16)
            }
            .foregroundStyle(Theme.Colors.text)
            .background(Theme.Colors.background.ignoresSafeArea())
            .navigationTitle(target.member == nil ? "Add family member" : "Edit family member")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let member = target.member {
                            appModel.updateFamilyMember(member, name: name, age: age, colorIndex: chosenColor)
                        } else {
                            appModel.addFamilyMember(named: name, age: age, colorIndex: chosenColor)
                        }
                        dismiss()
                    }
                    .disabled(name.cleanedTagName.isEmpty)
                }
            }
            .onAppear { if target.member == nil { isNameFocused = true } }
        }
        .tint(Theme.Colors.action)
        .presentationDetents([.large])
    }
}

#Preview {
    let appModel = AppViewModel.preview(withFamily: true)
    NavigationStack {
        ManageFamilyView()
    }
    .environment(appModel)
    .task { await appModel.start() }
}

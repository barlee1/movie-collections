//
//  WatchAndPlaceSheets.swift
//  MovieCollection
//
//  Purpose: Two small sheets from the detail screen: logging or editing one
//  watch (date, an optional note, and which family members were there), and moving a disc somewhere else,
//  including loaning it out.
//  Used in: TitleDetailView.
//

import SwiftUI

/// Log a new watch, or edit or delete an existing one.
struct WatchSheet: View {
    let titleName: String
    /// The watch being edited, or nil to log a new one.
    let watch: WatchEvent?
    /// Everyone who could have been there, in the user's order.
    let family: [FamilyMember]
    let onSave: (Date, String, [FamilyMember]) -> Void
    let onDelete: () -> Void

    @State private var date: Date
    @State private var note: String
    @State private var viewerIDs: Set<UUID>
    @Environment(\.dismiss) private var dismiss

    init(
        titleName: String,
        watch: WatchEvent?,
        family: [FamilyMember] = [],
        onSave: @escaping (Date, String, [FamilyMember]) -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.titleName = titleName
        self.watch = watch
        self.family = family
        self.onSave = onSave
        self.onDelete = onDelete
        _date = State(initialValue: watch?.date ?? .now)
        _note = State(initialValue: watch?.note ?? "")
        _viewerIDs = State(initialValue: Set(watch?.viewers.map(\.id) ?? []))
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Text(titleName)
                    .font(Theme.Fonts.heading(22, relativeTo: .title2))
                // Watches can't be in the future.
                DatePicker("Watched on", selection: $date, in: ...Date.now, displayedComponents: .date)
                    .font(Theme.Fonts.body(16))
                TextField("Note (optional), e.g. Movie night with the kids", text: $note, axis: .vertical)
                    .lineLimit(1...4)
                    .pillField()
                    .accessibilityIdentifier("watch.note")
                if !family.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionLabel(text: "Who was there?", size: 12)
                        FlowLayout(spacing: 8) {
                            ForEach(family) { member in
                                FamilyMemberChip(member: member, isOn: viewerIDs.contains(member.id)) {
                                    viewerIDs.toggle(member.id)
                                }
                            }
                        }
                    }
                }
                if watch != nil {
                    Button("Delete this watch", role: .destructive) {
                        onDelete()
                        dismiss()
                    }
                    .font(Theme.Fonts.body(15, weight: .semibold))
                    .foregroundStyle(Theme.Colors.error)
                    .frame(minHeight: 44)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Theme.Spacing.page)
            .padding(.vertical, 16)
            .foregroundStyle(Theme.Colors.text)
            .background(Theme.Colors.background.ignoresSafeArea())
            .navigationTitle(watch == nil ? "Log a watch" : "Edit watch")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(date, note.trimmed, family.filter { viewerIDs.contains($0.id) })
                        dismiss()
                    }
                }
            }
        }
        .tint(Theme.Colors.action)
        .presentationDetents(family.isEmpty ? [.medium] : [.medium, .large])
    }
}

/// Move a disc: Shelf, Loaned out (to whom, since when), or a custom place.
struct MoveDiscSheet: View {
    let title: OwnedTitle
    let locations: [StorageLocation]
    let onSave: (StorageLocation, String?, Date, Date?) -> Void

    @State private var selection: StorageLocation?
    @State private var loanedTo: String
    @State private var loanedOn: Date
    @State private var dueBack: Date?
    @Environment(\.dismiss) private var dismiss

    /// `onSave` gets the place, who has it, since when, and when it's due back.
    init(title: OwnedTitle, locations: [StorageLocation], onSave: @escaping (StorageLocation, String?, Date, Date?) -> Void) {
        self.title = title
        self.locations = locations
        self.onSave = onSave
        _selection = State(initialValue: title.storageLocation)
        _loanedTo = State(initialValue: title.loanedTo ?? "")
        _loanedOn = State(initialValue: title.loanedOn ?? .now)
        _dueBack = State(initialValue: title.loanDueOn)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                DiscLocationPicker(
                    locations: locations, selection: $selection, loanedTo: $loanedTo, loanedOn: $loanedOn,
                    dueBack: $dueBack)
                    // Full width, so the sheet doesn't shrink to a narrow column with fewer fields.
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Theme.Spacing.page)
                    .padding(.vertical, 16)
            }
            .foregroundStyle(Theme.Colors.text)
            .background(Theme.Colors.background.ignoresSafeArea())
            .navigationTitle("Where is it?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let selection {
                            let isLoan = selection.role == .loanedOut
                            onSave(selection, isLoan ? loanedTo : nil, loanedOn, isLoan ? dueBack : nil)
                        }
                        dismiss()
                    }
                    .disabled(selection == nil)
                }
            }
        }
        .tint(Theme.Colors.action)
        .presentationDetents([.medium, .large])
    }
}

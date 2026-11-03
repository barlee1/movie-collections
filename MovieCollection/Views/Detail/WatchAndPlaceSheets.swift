//
//  WatchAndPlaceSheets.swift
//  MovieCollection
//
//  Purpose: Two small sheets from the detail screen: logging or editing one
//  watch (date and an optional note), and moving a disc somewhere else,
//  including loaning it out.
//  Used in: TitleDetailView.
//

import SwiftUI

/// Log a new watch, or edit or delete an existing one.
struct WatchSheet: View {
    let titleName: String
    /// The watch being edited, or nil to log a new one.
    let watch: WatchEvent?
    let onSave: (Date, String) -> Void
    let onDelete: () -> Void

    @State private var date: Date
    @State private var note: String
    @Environment(\.dismiss) private var dismiss

    init(titleName: String, watch: WatchEvent?, onSave: @escaping (Date, String) -> Void, onDelete: @escaping () -> Void) {
        self.titleName = titleName
        self.watch = watch
        self.onSave = onSave
        self.onDelete = onDelete
        _date = State(initialValue: watch?.date ?? .now)
        _note = State(initialValue: watch?.note ?? "")
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
                        onSave(date, note.trimmed)
                        dismiss()
                    }
                }
            }
        }
        .tint(Theme.Colors.action)
        .presentationDetents([.medium])
    }
}

/// Move a disc: Shelf, Loaned out (to whom, since when), or a custom place.
struct MoveDiscSheet: View {
    let title: OwnedTitle
    let locations: [StorageLocation]
    let onSave: (StorageLocation, String?, Date) -> Void

    @State private var selection: StorageLocation?
    @State private var loanedTo: String
    @State private var loanedOn: Date
    @Environment(\.dismiss) private var dismiss

    init(title: OwnedTitle, locations: [StorageLocation], onSave: @escaping (StorageLocation, String?, Date) -> Void) {
        self.title = title
        self.locations = locations
        self.onSave = onSave
        _selection = State(initialValue: title.storageLocation)
        _loanedTo = State(initialValue: title.loanedTo ?? "")
        _loanedOn = State(initialValue: title.loanedOn ?? .now)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                DiscLocationPicker(locations: locations, selection: $selection, loanedTo: $loanedTo, loanedOn: $loanedOn)
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
                            onSave(selection, selection.role == .loanedOut ? loanedTo : nil, loanedOn)
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

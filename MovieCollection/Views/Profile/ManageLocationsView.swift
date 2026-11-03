//
//  ManageLocationsView.swift
//  MovieCollection
//
//  Purpose: Settings › Locations: every place a disc can be. Add one, tap to
//  rename, drag to reorder, swipe to delete (its discs move to the Shelf).
//  Shelf and Loaned out can be renamed but not deleted.
//  Used in: RootTabView (Route.manageLocations), opened from Settings.
//

import SwiftUI

struct ManageLocationsView: View {
    @Environment(AppViewModel.self) private var appModel
    @State private var newName = ""
    @State private var renaming: StorageLocation?
    @State private var renameText = ""
    @State private var deleting: StorageLocation?

    var body: some View {
        List {
            Section {
                HStack(spacing: 10) {
                    TextField("New place, e.g. Living room cabinet", text: $newName)
                        .font(Theme.Fonts.body(16))
                        .submitLabel(.done)
                        .onSubmit(add)
                        .accessibilityIdentifier("locations.newName")
                    Button("Add", action: add)
                        .font(Theme.Fonts.body(16, weight: .semibold))
                        .disabled(newName.cleanedTagName.isEmpty)
                }
            }

            Section {
                ForEach(appModel.locations) { location in
                    Button {
                        renameText = location.name
                        renaming = location
                    } label: {
                        row(location)
                    }
                    .buttonStyle(.plain)
                    .deleteDisabled(location.isBuiltIn)
                }
                .onMove(perform: move)
                .onDelete { offsets in
                    deleting = offsets.map { appModel.locations[$0] }.first
                }
            } footer: {
                Text("Tap a place to rename it. Drag to reorder. Shelf and Loaned out are built in, so they can be renamed but not deleted.")
                    .font(Theme.Fonts.body(13, relativeTo: .footnote))
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.Colors.background.ignoresSafeArea())
        .foregroundStyle(Theme.Colors.text)
        .tint(Theme.Colors.action)
        .environment(\.editMode, .constant(.active))
        .navigationTitle("Locations")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Rename location", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Name", text: $renameText)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                if let renaming { appModel.renameLocation(renaming, to: renameText) }
            }
        }
        .confirmationDialog(
            deleteTitle,
            isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let deleting { appModel.deleteLocation(deleting) }
            }
        } message: {
            Text(deleteMessage)
        }
    }

    private func row(_ location: StorageLocation) -> some View {
        HStack {
            Image(systemName: icon(for: location))
                .foregroundStyle(Theme.Colors.textMuted)
                .frame(width: 24)
                .accessibilityHidden(true)
            Text(location.name)
                .font(Theme.Fonts.body(16, weight: .semibold))
            Spacer()
            let count = location.titles.count
            Text("\(count) \(count == 1 ? "disc" : "discs")")
                .font(Theme.Fonts.body(14, relativeTo: .subheadline))
                .foregroundStyle(Theme.Colors.textMuted)
        }
        .contentShape(.rect)
        .accessibilityHint("Rename")
    }

    private func icon(for location: StorageLocation) -> String {
        switch location.role {
        case .shelf: "books.vertical"
        case .loanedOut: "person"
        case nil: "mappin"
        }
    }

    private var deleteTitle: String {
        "Delete \(deleting?.name ?? "this location")?"
    }

    /// e.g. "3 discs will move to Shelf."
    private var deleteMessage: String {
        let count = deleting?.titles.count ?? 0
        let shelf = appModel.location(.shelf)?.name ?? BuiltInLocation.shelf.defaultName
        return count == 0 ? "No discs are stored here." : "\(count) \(count == 1 ? "disc" : "discs") will move to \(shelf)."
    }

    private func add() {
        if appModel.addLocation(named: newName) != nil { newName = "" }
    }

    private func move(from source: IndexSet, to destination: Int) {
        var ordered = appModel.locations
        ordered.move(fromOffsets: source, toOffset: destination)
        appModel.reorderLocations(ordered)
    }
}

#Preview {
    let appModel = AppViewModel.preview()
    NavigationStack {
        ManageLocationsView()
    }
    .environment(appModel)
    .task { await appModel.start() }
}

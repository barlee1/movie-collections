//
//  OrganizingFields.swift
//  MovieCollection
//
//  Purpose: Form pieces shared by the add form and the edit sheet: where a
//  disc is (with who borrowed it when it's loaned out), and a title's tags.
//  Used in: AddTitleView, EditTitleSheet.
//

import SwiftUI

/// Chips for every location, plus "who has it" and "since" when Loaned out is picked.
struct DiscLocationPicker: View {
    let locations: [StorageLocation]
    @Binding var selection: StorageLocation?
    @Binding var loanedTo: String
    @Binding var loanedOn: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Where it is", size: 12)
            FlowLayout {
                ForEach(locations) { location in
                    ChipButton(label: location.name, isOn: selection === location, size: .small) {
                        selection = location
                    }
                }
            }
            if selection?.role == .loanedOut {
                VStack(alignment: .leading, spacing: 10) {
                    TextField("Who has it? e.g. Sam", text: $loanedTo)
                        .pillField()
                        .textContentType(.name)
                        .accessibilityIdentifier("location.loanedTo")
                    DatePicker("Since", selection: $loanedOn, in: ...Date.now, displayedComponents: .date)
                        .font(Theme.Fonts.body(16))
                }
                .padding(.top, 4)
                .transition(.opacity)
            }
            Text("Add your own places, like \"Living room cabinet\", in Settings › Locations.")
                .font(Theme.Fonts.body(12, relativeTo: .caption))
                .foregroundStyle(Theme.Colors.textMuted)
        }
        .animation(.snappy, value: selection?.role)
    }
}

/// A title's tags as chips, with a button that opens the tag picker.
struct TagsField: View {
    @Binding var tags: [Tag]
    @State private var isPicking = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Tags", size: 12)
            FlowLayout(spacing: 6) {
                ForEach(tags) { tag in
                    UserTagChip(tag: tag)
                }
                Button(tags.isEmpty ? "Add tags" : "Edit tags") { isPicking = true }
                    .buttonStyle(.pill(.secondary, typeface: .body, fontSize: 14, height: 32, fullWidth: false))
            }
        }
        .sheet(isPresented: $isPicking) {
            TagPickerSheet(selected: tags) { tags = $0 }
        }
    }
}

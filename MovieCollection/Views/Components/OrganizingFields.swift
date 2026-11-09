//
//  OrganizingFields.swift
//  MovieCollection
//
//  Purpose: Form pieces shared by the add form and the edit sheet: where a
//  disc is (with who borrowed it, since when, and an optional due-back date
//  when it's loaned out), and a title's tags.
//  Used in: AddTitleView, EditTitleSheet, MoveDiscSheet.
//

import SwiftUI

/// Chips for every location, plus "who has it", "since", and an optional
/// "due back" date when Loaned out is picked.
struct DiscLocationPicker: View {
    let locations: [StorageLocation]
    @Binding var selection: StorageLocation?
    @Binding var loanedTo: String
    @Binding var loanedOn: Date
    /// When it should come back, or nil for no date.
    @Binding var dueBack: Date?

    /// A new due date starts two weeks out.
    static let defaultLoanDays = 14

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
                    Toggle("Due back", isOn: hasDueDate)
                        .font(Theme.Fonts.body(16))
                        .tint(Theme.Colors.action)
                    if let due = dueBack {
                        DatePicker(
                            "Due back on",
                            selection: Binding(get: { due }, set: { dueBack = $0 }),
                            in: Calendar.current.startOfDay(for: .now)...,
                            displayedComponents: .date
                        )
                        .font(Theme.Fonts.body(16))
                        Text("You'll get a reminder that morning to ask for it back.")
                            .font(Theme.Fonts.body(12, relativeTo: .caption))
                            .foregroundStyle(Theme.Colors.textMuted)
                    }
                }
                .padding(.top, 4)
                .transition(.opacity)
            }
            Text("Add your own places, like \"Living room cabinet\", in Settings › Locations.")
                .font(Theme.Fonts.body(12, relativeTo: .caption))
                .foregroundStyle(Theme.Colors.textMuted)
        }
        .animation(.snappy, value: selection?.role)
        .animation(.snappy, value: dueBack == nil)
    }

    private var hasDueDate: Binding<Bool> {
        Binding(
            get: { dueBack != nil },
            set: { isOn in
                dueBack = isOn ? Calendar.current.date(byAdding: .day, value: Self.defaultLoanDays, to: .now) : nil
            }
        )
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

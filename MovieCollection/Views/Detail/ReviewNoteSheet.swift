//
//  ReviewNoteSheet.swift
//  MovieCollection
//
//  Purpose: A small sheet for writing just the review: the half-star rating and
//  a note. Nothing else about the title is shown, and nothing is saved until
//  Save is tapped.
//  Used in: TitleDetailView ("Add a note" / "Edit note").
//

import SwiftUI

struct ReviewNoteSheet: View {
    let titleName: String
    /// Called with the rating and the trimmed note when Save is tapped.
    let onSave: (_ rating: Double, _ note: String) -> Void

    // A draft, so Cancel leaves the saved review untouched.
    @State private var rating: Double
    @State private var note: String
    @FocusState private var isNoteFocused: Bool
    @Environment(\.dismiss) private var dismiss

    init(titleName: String, rating: Double, note: String, onSave: @escaping (_ rating: Double, _ note: String) -> Void) {
        self.titleName = titleName
        self.onSave = onSave
        _rating = State(initialValue: rating)
        _note = State(initialValue: note)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(titleName)
                        .font(Theme.Fonts.heading(26, relativeTo: .title))
                        .accessibilityAddTraits(.isHeader)

                    VStack(alignment: .leading, spacing: 10) {
                        SectionLabel(text: "Your rating", size: 12)
                        HalfStarPicker(rating: $rating, size: 30)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        SectionLabel(text: "Your note", size: 12)
                        TextField("What did you think?", text: $note, axis: .vertical)
                            .lineLimit(5...12)
                            .font(Theme.Fonts.body(16))
                            .focused($isNoteFocused)
                            .padding(14)
                            .background(Theme.Colors.tintMain, in: .rect(cornerRadius: Theme.Radius.md))
                            .overlay {
                                RoundedRectangle(cornerRadius: Theme.Radius.md).strokeBorder(Theme.Colors.divider)
                            }
                            .accessibilityIdentifier("reviewNote.text")
                    }
                }
                .padding(.horizontal, Theme.Spacing.page)
                .padding(.vertical, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .foregroundStyle(Theme.Colors.text)
            .background(Theme.Colors.background.ignoresSafeArea())
            .navigationTitle("Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(rating, note.trimmed)
                        dismiss()
                    }
                }
            }
            .onAppear { isNoteFocused = true }
        }
        .tint(Theme.Colors.action)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

#Preview {
    Text("Detail screen")
        .sheet(isPresented: .constant(true)) {
            ReviewNoteSheet(titleName: "Apollo 13", rating: 4.5, note: "") { _, _ in }
        }
}

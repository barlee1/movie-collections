//
//  EditTitleSheet.swift
//  MovieCollection
//
//  Purpose: Edit how the user has a title (format and service), where a disc
//  is (and who borrowed it), its film rating, tags, and their half-star
//  review. Also removes the title from the shelf. Watch history is edited on
//  the detail screen.
//  Used in: TitleDetailView.
//

import SwiftUI

struct EditTitleSheet: View {
    @State private var viewModel: EditTitleViewModel
    @State private var isConfirmingRemove = false
    @Environment(\.dismiss) private var dismiss
    /// Called after the title is removed, so the detail screen can close too.
    private let onRemoved: () -> Void

    init(title: OwnedTitle, appModel: AppViewModel, startWithReview: Bool = false, onRemoved: @escaping () -> Void) {
        _viewModel = State(initialValue: EditTitleViewModel(title: title, appModel: appModel, startWithReview: startWithReview))
        self.onRemoved = onRemoved
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text(viewModel.title.title)
                        .font(Theme.Fonts.heading(28, relativeTo: .title))
                        .accessibilityAddTraits(.isHeader)

                    locationSection
                    if viewModel.format.isPhysical {
                        DiscLocationPicker(
                            locations: viewModel.locationOptions,
                            selection: $viewModel.location,
                            loanedTo: $viewModel.loanedTo,
                            loanedOn: $viewModel.loanedOn,
                        dueBack: $viewModel.dueBack
                        )
                    }
                    ratingSection
                    TagsField(tags: $viewModel.tags)
                    reviewSection

                    Button("Remove from shelf", role: .destructive) {
                        isConfirmingRemove = true
                    }
                    .font(Theme.Fonts.body(15, weight: .semibold))
                    .foregroundStyle(Theme.Colors.error)
                    .frame(minHeight: 44)
                }
                .padding(.horizontal, Theme.Spacing.page)
                .padding(.vertical, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .foregroundStyle(Theme.Colors.text)
            .background(Theme.Colors.background.ignoresSafeArea())
            .navigationTitle("Edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if viewModel.save() { dismiss() }
                    }
                    .disabled(!viewModel.canSave)
                }
            }
            .confirmationDialog(
                "Remove \(viewModel.title.title) from your shelf?",
                isPresented: $isConfirmingRemove,
                titleVisibility: .visible
            ) {
                Button("Remove", role: .destructive) {
                    if viewModel.removeFromShelf() {
                        dismiss()
                        onRemoved()
                    }
                }
            } message: {
                Text("Your review of it will be deleted too.")
            }
        }
        .tint(Theme.Colors.action)
    }

    // MARK: - Sections

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Format", size: 12)
            FlowLayout {
                ForEach(MediaFormat.allCases) { format in
                    ChipButton(label: format.rawValue, isOn: viewModel.format == format, size: .small) {
                        viewModel.format = format
                    }
                }
            }
            if viewModel.format.needsService {
                SectionLabel(text: viewModel.format == .streaming ? "Streaming on" : "Digital copy on", size: 12)
                    .padding(.top, 6)
                FlowLayout {
                    ForEach(viewModel.format.allowedServices) { service in
                        ChipButton(label: service.rawValue, isOn: viewModel.service == service, size: .small) {
                            viewModel.service = service
                        }
                    }
                }
                if viewModel.needsService {
                    Text("Pick a service to save.")
                        .font(Theme.Fonts.body(13, relativeTo: .footnote))
                        .foregroundStyle(Theme.Colors.error)
                }
            }
        }
    }

    private var ratingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Film rating", size: 12)
            FlowLayout {
                ForEach(viewModel.title.kind.ratingOptions) { rating in
                    ChipButton(label: rating.label, isOn: viewModel.filmRating == rating, size: .small) {
                        viewModel.filmRating = viewModel.filmRating == rating ? nil : rating
                    }
                }
            }
        }
    }

    private var reviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: "Your review", size: 12)
            Toggle("I've reviewed it", isOn: $viewModel.hasReview.animation())
                .font(Theme.Fonts.body(16))
            if viewModel.hasReview {
                HalfStarPicker(rating: $viewModel.rating)
                    .accessibilityIdentifier("edit.rating")
                TextField("What did you think?", text: $viewModel.reviewText, axis: .vertical)
                    .accessibilityIdentifier("edit.reviewText")
                    .lineLimit(4...10)
                    .font(Theme.Fonts.body(15))
                    .padding(14)
                    .background(Theme.Colors.tintMain, in: .rect(cornerRadius: Theme.Radius.md))
                    .overlay {
                        RoundedRectangle(cornerRadius: Theme.Radius.md).strokeBorder(Theme.Colors.divider)
                    }
            }
        }
    }
}

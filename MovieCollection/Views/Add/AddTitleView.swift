//
//  AddTitleView.swift
//  MovieCollection
//
//  Purpose: The "Type it in" form. As the user types a title, catalog matches
//  appear; tapping one fills in every field. Everything stays editable, and
//  titles not in the catalog can be entered by hand.
//  Used in: RootTabView (Route.addTitle), opened from the Add tab.
//

import SwiftUI

struct AddTitleView: View {
    @State private var viewModel: AddTitleViewModel
    @Environment(AppRouter.self) private var router
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case title, year, runtime, director, cast, genres
    }

    /// - Parameter prefill: A catalog movie to fill the form with (from the cover scanner).
    init(appModel: AppViewModel, prefill: Movie? = nil) {
        let viewModel = AddTitleViewModel(appModel: appModel)
        if let prefill { viewModel.pick(prefill) }
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                BackButton()
                ScreenHeader(title: "Type it in", subtitle: "Start typing to find it in our catalog, or fill in everything yourself.", titleSize: 34)

                titleSection
                kindSection
                detailsSection
                ratingSection
                locationSection
                if viewModel.format.isPhysical {
                    DiscLocationPicker(
                        locations: viewModel.locationOptions,
                        selection: Binding(
                            get: { viewModel.location ?? viewModel.locationOptions.first { $0.role == .shelf } },
                            set: { viewModel.location = $0 }
                        ),
                        loanedTo: $viewModel.loanedTo,
                        loanedOn: $viewModel.loanedOn
                    )
                }
                TagsField(tags: $viewModel.tags)
                watchedSection
            }
            .padding(.horizontal, Theme.Spacing.page)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .themedScreen()
        .safeAreaInset(edge: .bottom, spacing: 0) {
            saveBar
        }
        .onAppear { focusedField = .title }
        // A movie from the cover scanner may need its details fetched.
        .task { await viewModel.completePickedDetails() }
        // Restarts on each keystroke, cancelling the previous TMDB search.
        .task(id: viewModel.title) { await viewModel.searchOnline() }
    }

    // MARK: - Sections

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Title", size: 12)
            TextField("e.g. The Lake House", text: $viewModel.title)
                .pillField()
                .focused($focusedField, equals: .title)
                .submitLabel(.next)
                .accessibilityIdentifier("addTitle.title")

            // Catalog suggestions while typing.
            if !viewModel.suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(viewModel.suggestions) { movie in
                        Button {
                            focusedField = nil
                            Task { await viewModel.choose(movie) }
                        } label: {
                            suggestionRow(movie)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("addTitle.suggestion")
                        if movie.id != viewModel.suggestions.last?.id {
                            Rectangle().fill(Theme.Colors.divider).frame(height: 1)
                        }
                    }
                }
                .background(Theme.Colors.surface, in: .rect(cornerRadius: Theme.Radius.md))
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.Radius.md).strokeBorder(Theme.Colors.divider)
                }
            }

            if viewModel.isLoadingDetails {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Filling in the details…")
                }
                .font(Theme.Fonts.body(13, relativeTo: .footnote))
                .foregroundStyle(Theme.Colors.textMuted)
            }

            if viewModel.isAlreadyOnShelf {
                Text("This one is already on your shelf. You can still add another copy.")
                    .font(Theme.Fonts.body(13, relativeTo: .footnote))
                    .foregroundStyle(Theme.Colors.error)
            }
        }
    }

    private func suggestionRow(_ movie: Movie) -> some View {
        HStack(spacing: 12) {
            PosterArt(title: movie.title, letter: movie.posterLetter)
                .frame(width: 30, height: 42)
                .clipShape(.rect(cornerRadius: 6))
            VStack(alignment: .leading, spacing: 2) {
                Text(movie.title)
                    .font(Theme.Fonts.body(15, weight: .semibold))
                    .foregroundStyle(Theme.Colors.text)
                    .multilineTextAlignment(.leading)
                // TMDB search results don't have a director yet, so skip empty parts.
                Text([movie.year.map(String.init), movie.filmRating?.label, movie.director].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(Theme.Fonts.body(13, relativeTo: .footnote))
                    .foregroundStyle(Theme.Colors.textMuted)
            }
            Spacer(minLength: 0)
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(Theme.Colors.action)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Fills in the details")
    }

    private var kindSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Type", size: 12)
            FlowLayout {
                ForEach(TitleKind.allCases) { kind in
                    ChipButton(label: kind.rawValue, isOn: viewModel.kind == kind, size: .small) {
                        viewModel.kind = kind
                    }
                }
            }
        }
    }

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                field(
                    "Year", placeholder: "e.g. 2006", text: $viewModel.yearText, focus: .year,
                    error: viewModel.yearIsValid ? nil : "Enter a 4-digit year"
                )
                .keyboardType(.numberPad)
                field(
                    "Runtime (min)", placeholder: "e.g. 99", text: $viewModel.runtimeText, focus: .runtime,
                    error: viewModel.runtimeIsValid ? nil : "Enter minutes"
                )
                .keyboardType(.numberPad)
            }
            field(viewModel.kind.directorLabel, placeholder: "e.g. Alejandro Agresti", text: $viewModel.director, focus: .director)
            field("Cast", placeholder: "Names, separated by commas", text: $viewModel.castText, focus: .cast)
            field("Genres", placeholder: "e.g. Romance, Drama", text: $viewModel.genresText, focus: .genres)
        }
    }

    private var ratingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Film rating", size: 12)
            FlowLayout {
                ForEach(viewModel.kind.ratingOptions) { rating in
                    ChipButton(label: rating.label, isOn: viewModel.filmRating == rating, size: .small) {
                        viewModel.filmRating = viewModel.filmRating == rating ? nil : rating
                    }
                }
            }
        }
    }

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
            }
        }
    }

    private var watchedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Watched", size: 12)
            Toggle("I've watched it", isOn: $viewModel.hasWatched.animation())
                .font(Theme.Fonts.body(16))
                .tint(Theme.Colors.action)
            if viewModel.hasWatched {
                DatePicker("Date", selection: $viewModel.lastWatched, in: ...Date.now, displayedComponents: .date)
                    .font(Theme.Fonts.body(16))
                    .tint(Theme.Colors.action)
            }
        }
    }

    /// The sticky "Add to shelf" bar, with a hint about what's missing.
    private var saveBar: some View {
        VStack(spacing: 8) {
            Button("Add to shelf") {
                if let id = viewModel.save() {
                    router.replaceTop(with: .titleDetail(id))
                }
            }
            .buttonStyle(.pill(.primary, height: 52))
            .disabled(!viewModel.canSave)

            if let hint = saveHint {
                Text(hint)
                    .font(Theme.Fonts.body(13, relativeTo: .footnote))
                    .foregroundStyle(Theme.Colors.textMuted)
            }
        }
        .padding(.horizontal, Theme.Spacing.page)
        .padding(.top, 14)
        .padding(.bottom, 16)
        .background(Theme.Colors.background)
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.Colors.divider).frame(height: 1)
        }
    }

    private var saveHint: String? {
        if viewModel.title.trimmed.isEmpty { return "Add a title to save." }
        if viewModel.needsService { return "Pick where you have it to save." }
        if !viewModel.yearIsValid || !viewModel.runtimeIsValid { return "Fix the highlighted fields to save." }
        return nil
    }

    // MARK: - Builders

    private func field(_ label: String, placeholder: String, text: Binding<String>, focus: Field, error: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: label, size: 12)
            TextField(placeholder, text: text)
                .pillField()
                .focused($focusedField, equals: focus)
                .overlay {
                    if error != nil {
                        Capsule().strokeBorder(Theme.Colors.error, lineWidth: 1.5)
                    }
                }
            if let error {
                Text(error)
                    .font(Theme.Fonts.body(12, relativeTo: .caption))
                    .foregroundStyle(Theme.Colors.error)
            }
        }
    }
}

#Preview {
    let appModel = AppViewModel.preview()
    NavigationStack {
        AddTitleView(appModel: appModel)
    }
    .environment(appModel)
    .environment(AppRouter())
    .task { await appModel.start() }
}

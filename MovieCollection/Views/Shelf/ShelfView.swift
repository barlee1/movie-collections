//
//  ShelfView.swift
//  MovieCollection
//
//  Purpose: The Shelf tab: the collection as a poster grid with the standard
//  iOS search field (suggestion tokens and review scopes), a Sort menu, and
//  a Filter sheet. An empty shelf explains the app and points to Add.
//  Used in: RootTabView (Shelf tab).
//

import SwiftData
import SwiftUI

struct ShelfView: View {
    @State private var viewModel: ShelfViewModel

    init(appModel: AppViewModel) {
        _viewModel = State(initialValue: ShelfViewModel(appModel: appModel))
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        ShelfContent(viewModel: viewModel)
            .navigationTitle("Your shelf")
            .toolbarTitleDisplayMode(.large)
            .toolbar {
                // The design's display font for the large title.
                ToolbarItem(placement: .largeTitle) {
                    Text("Your shelf")
                        .font(Theme.Fonts.heading(40, relativeTo: .largeTitle))
                        .foregroundStyle(Theme.Colors.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityAddTraits(.isHeader)
                }
                ToolbarItem(placement: .largeSubtitle) {
                    Text(subtitle)
                        .font(Theme.Fonts.body(15, relativeTo: .subheadline))
                        .foregroundStyle(Theme.Colors.textMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if !viewModel.appModel.titles.isEmpty {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        // The field also appears by pulling the shelf down, like other iOS apps.
                        Button {
                            viewModel.isSearchPresented = true
                        } label: {
                            Label("Search", systemImage: "magnifyingglass")
                        }
                        sortMenu
                        filterButton
                    }
                }
            }
            .searchable(
                text: $viewModel.query,
                tokens: $viewModel.tokens,
                isPresented: $viewModel.isSearchPresented,
                placement: .navigationBarDrawer,
                prompt: "Title, director, cast, or genre"
            ) { token in
                Label(token.label, systemImage: token.kind.systemImage)
            }
            .searchSuggestions {
                ForEach(viewModel.suggestions) { token in
                    Label(token.label, systemImage: token.kind.systemImage)
                        .searchCompletion(token)
                }
            }
            .searchScopes($viewModel.seen, activation: .onSearchPresentation) {
                ForEach(ShelfViewModel.SeenFilter.allCases) { scope in
                    Text(scope.rawValue).tag(scope)
                }
            }
            .sheet(isPresented: $viewModel.isFilterSheetOpen) {
                ShelfFilterSheet(viewModel: viewModel)
            }
            .themedScreen(showsNavigationBar: true)
    }

    /// e.g. "30 titles · 28 not reviewed yet · Sorted by last watched"
    private var subtitle: String {
        [viewModel.subtitle, viewModel.appModel.titles.isEmpty ? nil : viewModel.sortOrder.summary]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    private var sortMenu: some View {
        Menu {
            Picker("Sort by", selection: $viewModel.sortOrder) {
                ForEach(ShelfSortOrder.allCases) { order in
                    Label(order.rawValue, systemImage: order.systemImage).tag(order)
                }
            }
        } label: {
            Label("Sort", systemImage: "arrow.up.arrow.down")
        }
        .accessibilityValue(viewModel.sortOrder.rawValue)
    }

    private var filterButton: some View {
        let count = viewModel.filters.activeCount
        return Button {
            viewModel.isFilterSheetOpen = true
        } label: {
            Label("Filter", systemImage: count > 0 ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
        }
        .accessibilityValue(count > 0 ? "\(count) on" : "")
    }
}

/// Everything under the search field. A separate view so it can read
/// `isSearching`, which only works inside the searchable view.
private struct ShelfContent: View {
    @Bindable var viewModel: ShelfViewModel
    @Environment(AppRouter.self) private var router
    @Environment(\.cardZoomNamespace) private var cardZoomNamespace
    @Environment(\.isSearching) private var isSearching

    /// Two posters across in portrait; more fit as the screen widens (landscape).
    private let columns = [GridItem(.adaptive(minimum: 150, maximum: 220), spacing: 14)]

    var body: some View {
        let titles = viewModel.visibleTitles

        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if viewModel.appModel.titles.isEmpty {
                    emptyShelf
                } else {
                    // While searching, the scope bar under the field replaces these.
                    if !isSearching {
                        WatchProgressBar(watched: viewModel.appModel.watchedCount, total: viewModel.appModel.titles.count)
                        seenChips
                    }
                    if titles.isEmpty {
                        noResults
                    } else {
                        posterGrid(titles)
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.page)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .scrollDismissesKeyboard(.immediately)
    }

    // MARK: - Pieces

    private func posterGrid(_ titles: [OwnedTitle]) -> some View {
        LazyVGrid(columns: columns, spacing: 14) {
            ForEach(titles) { title in
                Button {
                    // Open the flip-card viewer at this title. Next/previous
                    // follow the shelf as it's currently searched, filtered, and sorted.
                    router.push(
                        .titleDeck(
                            ids: titles.map(\.persistentModelID),
                            startID: title.persistentModelID
                        ))
                } label: {
                    ShelfPosterCard(
                        title: title.title,
                        letter: title.posterLetter,
                        meta: ShelfViewModel.meta(for: title),
                        format: title.format,
                        isReviewed: title.isReviewed
                    )
                }
                .buttonStyle(.pressableCard)
                .cardZoomSource(id: title.persistentModelID, in: cardZoomNamespace)
            }
        }
    }

    /// The review chips, plus a reminder when filters are on.
    private var seenChips: some View {
        FlowLayout {
            ForEach(ShelfViewModel.SeenFilter.allCases) { option in
                ChipButton(label: option.rawValue, isOn: viewModel.seen == option) {
                    viewModel.seen = option
                }
            }
            if viewModel.filters.activeCount > 0 {
                Button("Clear filters") { viewModel.clearFilters() }
                    .font(Theme.Fonts.body(14, weight: .semibold))
                    .foregroundStyle(Theme.Colors.link)
                    .padding(.horizontal, 6)
                    .frame(minHeight: 44)
            }
        }
    }

    /// A brand-new (or emptied) shelf: what the app does and how to start.
    private var emptyShelf: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your shelf is empty")
                .font(Theme.Fonts.heading(20, relativeTo: .title3))
            Text(
                "Add the movies and shows you own or stream. Then flip through them, check off what you've watched, rate them, and let Tonight pick one for you."
            )
            .font(Theme.Fonts.body(15))
            Button("Add your first movie") { router.select(.add) }
                .buttonStyle(.pill(.primary, typeface: .body, fontSize: 15, height: 42, fullWidth: false))
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.surface, in: .rect(cornerRadius: Theme.Radius.poster))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Radius.poster).strokeBorder(Theme.Colors.divider)
        }
        .accessibilityElement(children: .contain)
    }

    /// iOS's standard "No results" view, with a way back to the whole shelf.
    private var noResults: some View {
        VStack(spacing: 12) {
            if viewModel.query.trimmed.isEmpty {
                ContentUnavailableView("Nothing matches", systemImage: "line.3.horizontal.decrease.circle", description: Text("Try fewer filters."))
            } else {
                ContentUnavailableView.search(text: viewModel.query)
            }
            Button("Show everything") { viewModel.showEverything() }
                .buttonStyle(.pill(.primary, typeface: .body, fontSize: 15, height: 42, fullWidth: false))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 24)
    }
}

#Preview {
    let appModel = AppViewModel.preview()
    NavigationStack {
        ShelfView(appModel: appModel)
    }
    .environment(appModel)
    .environment(AppRouter())
    .task { await appModel.start() }
}

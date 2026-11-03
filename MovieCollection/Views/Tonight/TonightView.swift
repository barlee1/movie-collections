//
//  TonightView.swift
//  MovieCollection
//
//  Purpose: The Tonight tab: narrow the shelf by mood, genre, runtime,
//  format, reviewed state, and film rating, then pick one at random.
//  Used in: RootTabView (Tonight tab).
//

import SwiftUI

struct TonightView: View {
    @Environment(TonightViewModel.self) private var viewModel
    @Environment(AppRouter.self) private var router
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private var isLandscape: Bool { verticalSizeClass == .compact }

    var body: some View {
        @Bindable var viewModel = viewModel

        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ScreenHeader(title: "Tonight", subtitle: "Narrow your shelf down to what fits the mood.")

                if viewModel.appModel.titles.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Add a few movies to your shelf, and Tonight will pick one that fits the mood.")
                            .font(Theme.Fonts.body(15))
                        Button("Add movies") { router.select(.add) }
                            .buttonStyle(.pill(.primary, typeface: .body, fontSize: 15, height: 40, fullWidth: false))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardStyle(background: Theme.Colors.tintSecondary)
                    .accessibilityElement(children: .contain)
                }

                group("Mood", scrolls: true) {
                    ForEach(Mood.allCases) { mood in
                        ChipButton(label: mood.rawValue, isOn: viewModel.moods.contains(mood)) {
                            viewModel.moods.toggle(mood)
                        }
                    }
                }

                group("Genre", scrolls: true) {
                    ForEach(viewModel.genreOptions, id: \.self) { genre in
                        ChipButton(label: genre, isOn: viewModel.genres.contains(genre)) {
                            viewModel.genres.toggle(genre)
                        }
                    }
                }

                if !viewModel.tagOptions.isEmpty {
                    group("Tags", scrolls: true) {
                        ForEach(viewModel.tagOptions) { tag in
                            ChipButton(label: tag.name, isOn: viewModel.tagIDs.contains(tag.id)) {
                                viewModel.tagIDs.toggle(tag.id)
                            }
                        }
                    }
                }

                group("Runtime") {
                    ForEach(TonightViewModel.RuntimeLimit.allCases) { limit in
                        ChipButton(label: limit.rawValue, isOn: viewModel.runtime == limit) {
                            viewModel.runtime = limit
                        }
                    }
                }

                group("Format") {
                    ChipButton(label: "Any", isOn: viewModel.format == nil) { viewModel.format = nil }
                    ForEach(MediaFormat.allCases) { format in
                        ChipButton(label: format.rawValue, isOn: viewModel.format == format) {
                            viewModel.format = format
                        }
                    }
                }

                group("Reviewed it?") {
                    ForEach(TonightViewModel.SeenOption.allCases) { option in
                        ChipButton(label: option.rawValue, isOn: viewModel.seen == option) {
                            viewModel.seen = option
                        }
                    }
                }

                group("Your rating") {
                    ForEach(TonightViewModel.StarFilter.allCases) { option in
                        ChipButton(label: option.rawValue, isOn: viewModel.yourRating == option) {
                            viewModel.yourRating = option
                        }
                    }
                }

                if let note = viewModel.adjustmentNote {
                    Label(note, systemImage: "info.circle")
                        .font(Theme.Fonts.body(13, relativeTo: .footnote))
                        .foregroundStyle(Theme.Colors.textMuted)
                        .padding(.top, -12)
                        .transition(.opacity)
                }

                group("Film rating") {
                    ForEach(viewModel.ratingOptions) { rating in
                        ChipButton(label: rating.label, isOn: viewModel.ratings.contains(rating)) {
                            viewModel.ratings.toggle(rating)
                        }
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.page)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .themedScreen()
        .safeAreaInset(edge: .bottom, spacing: 0) {
            pickBar
        }
    }

    // MARK: - Pieces

    /// A labeled row of chips. Mood and Genre scroll sideways; the rest wrap.
    @ViewBuilder
    private func group<Chips: View>(_ title: String, scrolls: Bool = false, @ViewBuilder chips: () -> Chips) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: title)
            if scrolls {
                // In portrait the row runs to the screen edges, like the design. In
                // landscape it stays inside the page so it clears the rounded corners.
                let edgeBleed = isLandscape ? 0 : Theme.Spacing.page
                ScrollView(.horizontal) {
                    HStack(spacing: 8) { chips() }
                        .padding(.horizontal, edgeBleed)
                }
                .scrollIndicators(.hidden)
                .padding(.horizontal, -edgeBleed)
            } else {
                FlowLayout { chips() }
            }
        }
    }

    /// The sticky bottom bar with "Pick one for me" and the match count.
    private var pickBar: some View {
        // Portrait stacks the count under the button; landscape puts them on one
        // line to save height.
        let layout =
            isLandscape
            ? AnyLayout(HStackLayout(spacing: 16))
            : AnyLayout(VStackLayout(spacing: 8))
        return layout {
            Button("Pick one for me") {
                if let id = viewModel.pick() {
                    router.push(.titleDetail(id, fromTonight: true))
                }
            }
            .buttonStyle(.pill(.primary, typeface: .body, fontSize: 17, height: isLandscape ? 44 : 52))
            .disabled(viewModel.matches.isEmpty)

            Text(viewModel.matchLabel)
                .font(Theme.Fonts.body(13, relativeTo: .footnote))
                .foregroundStyle(Theme.Colors.textMuted)
                .contentTransition(.numericText())
                .animation(.snappy, value: viewModel.matches.count)
                .fixedSize()
        }
        .padding(.horizontal, Theme.Spacing.page)
        .padding(.top, isLandscape ? 8 : 14)
        .padding(.bottom, isLandscape ? 8 : 16)
        .background(Theme.Colors.background)
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.Colors.divider).frame(height: 1)
        }
    }
}

#Preview {
    let appModel = AppViewModel.preview()
    NavigationStack {
        TonightView()
    }
    .environment(appModel)
    .environment(TonightViewModel(appModel: appModel))
    .environment(AppRouter())
    .task { await appModel.start() }
}

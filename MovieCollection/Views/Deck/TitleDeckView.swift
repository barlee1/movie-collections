//
//  TitleDeckView.swift
//  MovieCollection
//
//  Purpose: The flip-card viewer opened from the shelf. Cards sit side by side
//  with their neighbors peeking in; tap the centered card to flip it to its
//  details, and swipe or use the arrow buttons to move to the next or
//  previous title.
//  Used in: RootTabView (Route.titleDeck), opened by tapping a shelf poster.
//

import SwiftData
import SwiftUI

struct TitleDeckView: View {
    @State private var viewModel: TitleDeckViewModel
    @Environment(AppRouter.self) private var router

    /// Compact height means landscape on iPhone: arrows move beside the card.
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    /// Space between cards in the row.
    private let cardSpacing: CGFloat = 16

    init(ids: [PersistentIdentifier], startID: PersistentIdentifier, appModel: AppViewModel) {
        _viewModel = State(initialValue: TitleDeckViewModel(ids: ids, startID: startID, appModel: appModel))
    }

    private var isLandscape: Bool { verticalSizeClass == .compact }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                BackButton()
                Spacer()
                // In landscape the counter moves up here to leave room for the cards.
                if isLandscape, !viewModel.titles.isEmpty {
                    positionLabel
                }
            }
            .padding(.horizontal, Theme.Spacing.page)

            if viewModel.titles.isEmpty {
                Text("These titles are no longer on your shelf.")
                    .font(Theme.Fonts.body(16))
                    .foregroundStyle(Theme.Colors.textMuted)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if isLandscape {
                // Landscape: arrows sit on either side of the cards.
                HStack(spacing: 8) {
                    previousButton
                    cardRow
                    nextButton
                }
                .padding(.horizontal, Theme.Spacing.page)
                .padding(.bottom, 8)
            } else {
                // Portrait: the cards, then arrows on either side of the counter.
                cardRow
                HStack(spacing: 16) {
                    previousButton
                    VStack(spacing: 2) {
                        positionLabel
                        flipHint
                    }
                    .frame(maxWidth: .infinity)
                    nextButton
                }
                .padding(.horizontal, Theme.Spacing.page)
                .frame(height: 96)
            }
        }
        .themedScreen()
        .sensoryFeedback(.selection, trigger: viewModel.currentID)
        .sensoryFeedback(.impact(weight: .light), trigger: viewModel.flippedID)
        .onChange(of: viewModel.titles.count) { viewModel.recoverIfCurrentRemoved() }
    }

    // MARK: - Cards

    private var cardRow: some View {
        GeometryReader { geometry in
            // Size cards to fit both portrait and landscape: as wide as possible,
            // but never taller than the space available (cards are 2:3).
            // The space left over lets the neighboring cards peek in.
            let peek: CGFloat = isLandscape ? 80 : 120
            let cardWidth = max(min(geometry.size.width - peek, (geometry.size.height - 16) * 2 / 3), 80)
            let sideMargin = max((geometry.size.width - cardWidth) / 2, 0)

            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    LazyHStack(spacing: cardSpacing) {
                        ForEach(viewModel.titles) { title in
                            card(for: title, width: cardWidth)
                                .frame(width: cardWidth, height: cardWidth * 3 / 2)
                                // Neighbors shrink, fade, and angle away, like cards in a fanned deck.
                                .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                                    content
                                        .scaleEffect(phase.isIdentity ? 1 : 0.86)
                                        .opacity(phase.isIdentity ? 1 : 0.55)
                                        .rotation3DEffect(.degrees(phase.value * -12), axis: (x: 0, y: 1, z: 0))
                                }
                        }
                    }
                    .scrollTargetLayout()
                }
                .contentMargins(.horizontal, sideMargin, for: .scrollContent)
                .scrollTargetBehavior(.viewAligned)
                .scrollPosition(id: $viewModel.currentID)
                .scrollIndicators(.hidden)
                .frame(maxHeight: .infinity)
                // After rotating, re-center the current card in the new width.
                .onChange(of: geometry.size) {
                    if let currentID = viewModel.currentID {
                        proxy.scrollTo(currentID, anchor: .center)
                    }
                }
            }
        }
    }

    private func card(for title: OwnedTitle, width: CGFloat) -> some View {
        let isFlipped = viewModel.isFlipped(title)
        return FlipCard(isFlipped: isFlipped) {
            ShelfPosterCard(
                title: title.title,
                letter: title.posterLetter,
                meta: ShelfViewModel.meta(for: title),
                format: title.format,
                isReviewed: title.isReviewed,
                aspectRatio: 2 / 3,
                // Title text scales with the card, so small landscape cards stay readable.
                titleSize: min(30, max(16, width * 0.1))
            )
        } back: {
            CardBack(title: title, isCompact: width < 220) {
                router.push(.titleDetail(title.persistentModelID))
            }
        }
        .themeShadow(.md)
        .contentShape(.rect(cornerRadius: Theme.Radius.poster))
        .onTapGesture { flipOrSelect(title) }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(isFlipped ? "Shows the poster" : "Shows the details")
        .accessibilityAction(named: isFlipped ? "Show poster" : "Show details") { flipOrSelect(title) }
    }

    private func flipOrSelect(_ title: OwnedTitle) {
        withAnimation(.spring(duration: 0.55, bounce: 0.2)) {
            viewModel.tap(title)
        }
    }

    // MARK: - Controls

    private var previousButton: some View {
        DeckArrowButton(systemImage: "chevron.left", label: "Previous title", isEnabled: viewModel.canGoPrevious) {
            withAnimation(.snappy(duration: 0.35)) { viewModel.goPrevious() }
        }
    }

    private var nextButton: some View {
        DeckArrowButton(systemImage: "chevron.right", label: "Next title", isEnabled: viewModel.canGoNext) {
            withAnimation(.snappy(duration: 0.35)) { viewModel.goNext() }
        }
    }

    /// e.g. "4 of 30"
    private var positionLabel: some View {
        Text(viewModel.positionLabel)
            .font(Theme.Fonts.body(16, weight: .bold, relativeTo: .headline))
            .monospacedDigit()
            .contentTransition(.numericText())
            .animation(.snappy, value: viewModel.currentID)
    }

    private var flipHint: some View {
        Text(viewModel.isCurrentFlipped ? "Tap the card to see the poster" : "Tap the card to flip it")
            .font(Theme.Fonts.body(13, relativeTo: .footnote))
            .foregroundStyle(Theme.Colors.textMuted)
            .contentTransition(.opacity)
            .animation(.snappy, value: viewModel.flippedID)
    }
}

// MARK: - Arrow button

/// A round, filled arrow button that fades out at the ends of the deck.
private struct DeckArrowButton: View {
    let systemImage: String
    let label: String
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Theme.Colors.onAction)
                .frame(width: 56, height: 56)
                .background(Theme.Colors.action, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.pressableCard)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.3)
        .animation(.snappy, value: isEnabled)
        .accessibilityLabel(label)
    }
}

// MARK: - Card back

/// The details side of a flip card.
private struct CardBack: View {
    let title: OwnedTitle
    /// Smaller type and padding for the small cards in landscape.
    var isCompact = false
    let openDetails: () -> Void

    private var bodySize: CGFloat { isCompact ? 13 : 15 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: isCompact ? 8 : 14) {
                    Text(title.title)
                        .font(Theme.Fonts.heading(isCompact ? 18 : 26, relativeTo: .title))
                        .fixedSize(horizontal: false, vertical: true)

                    if let subtitle {
                        Text(subtitle)
                            .font(Theme.Fonts.body(bodySize - 1, relativeTo: .subheadline))
                            .foregroundStyle(Theme.Colors.textMuted)
                    }

                    FlowLayout(spacing: 6) {
                        TagView(
                            text: title.format.locationLabel, style: title.format.tagStyle,
                            systemImage: title.format.systemImage)
                        if let service = title.service {
                            TagView(text: service.rawValue, style: .neutral)
                        }
                        if let place = TitleDetailViewModel.placeText(for: title) {
                            TagView(text: place, style: .neutral, systemImage: title.isLoanedOut ? "person.fill" : "mappin")
                        }
                    }

                    if !title.tags.isEmpty {
                        FlowLayout(spacing: 6) {
                            ForEach(title.sortedTags) { tag in
                                UserTagChip(tag: tag, isCompact: isCompact)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(TitleDetailViewModel.detailRows(for: title)) { row in
                            Text("\(Text("\(row.label):").font(Theme.Fonts.body(bodySize, weight: .bold))) \(row.value)")
                                .font(Theme.Fonts.body(bodySize))
                        }
                    }

                    reviewSection

                    TagView(
                        text: TitleDetailViewModel.watchedLabel(for: title), style: .secondary,
                        systemImage: "calendar")

                    if let trailerURL = title.trailerURL {
                        Link(destination: trailerURL) {
                            Label("Watch trailer", systemImage: "play.rectangle")
                                .font(Theme.Fonts.body(bodySize, weight: .bold))
                        }
                        .tint(Theme.Colors.link)
                        .accessibilityHint("Opens YouTube")
                    }
                }
                .padding(isCompact ? 12 : 18)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.hidden)

            Button(isCompact ? "Details" : "Open full details", action: openDetails)
                .buttonStyle(.pill(.secondary, fontSize: isCompact ? 13 : 15, height: isCompact ? 36 : 44))
                .padding([.horizontal, .bottom], isCompact ? 10 : 16)
                .padding(.top, isCompact ? 4 : 8)
                .accessibilityLabel("Open full details")
        }
        .foregroundStyle(Theme.Colors.text)
        // The surface color (not a tint) so the tinted tags on the card stay visible.
        .background(Theme.Colors.surface, in: .rect(cornerRadius: Theme.Radius.poster))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Radius.poster).strokeBorder(Theme.Colors.divider)
        }
    }

    /// e.g. "Romance, Drama · 1h 39m"
    private var subtitle: String? {
        let parts = [
            title.genres.isEmpty ? nil : title.genres.prefix(3).joined(separator: ", "),
            title.runtime.map(TitleDisplay.runtimeText(minutes:)),
        ].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    @ViewBuilder
    private var reviewSection: some View {
        if let review = title.review {
            VStack(alignment: .leading, spacing: 6) {
                StarRatingView(rating: review.rating, size: isCompact ? 13 : 16)
                if !review.text.isEmpty {
                    Text(review.text)
                        .font(Theme.Fonts.body(bodySize - 1, relativeTo: .subheadline))
                        .lineSpacing(2)
                        .lineLimit(5)
                }
            }
        } else {
            TagView(text: "Not reviewed yet", style: .neutral)
        }
    }
}

#Preview {
    let appModel = AppViewModel.preview()
    PreviewDeck(appModel: appModel)
        .environment(appModel)
        .environment(AppRouter())
        .task { await appModel.start() }
}

/// Waits for the preview shelf to load, then shows it as a deck.
private struct PreviewDeck: View {
    let appModel: AppViewModel

    var body: some View {
        if let first = appModel.titles.first {
            NavigationStack {
                TitleDeckView(
                    ids: appModel.titles.map(\.persistentModelID), startID: first.persistentModelID,
                    appModel: appModel)
            }
        } else {
            ProgressView()
        }
    }
}

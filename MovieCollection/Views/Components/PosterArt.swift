//
//  PosterArt.swift
//  MovieCollection
//
//  Purpose: Placeholder poster artwork (a big letter on a warm colored tile)
//  and the shelf's poster card built on top of it.
//  Used in: Shelf grid (ShelfPosterCard), movie detail, review cards (PosterArt).
//

import SwiftUI

// MARK: - Poster art

/// A warm tile with the title's letter. Each title always gets the same
/// colors, so a movie looks the same everywhere in the app.
struct PosterArt: View {
    let title: String
    let letter: String
    /// Where the letter sits vertically, from 0 (top) to 1 (bottom).
    /// Shelf cards raise it so the title text below doesn't cover it.
    var letterHeight: CGFloat = 0.5

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let palette = PosterPalette.colors(for: title)
            ZStack {
                palette.base
                // A soft circle in the corner, the design system's "blob" decoration.
                // Drawn in a Canvas so the overhang doesn't stretch the poster's
                // accessibility frame past its edges (a positioned Circle view did).
                Canvas { context, canvasSize in
                    let diameter = canvasSize.width * 1.1
                    let center = CGPoint(x: canvasSize.width * 0.9, y: canvasSize.height * 0.12)
                    let circle = CGRect(
                        x: center.x - diameter / 2, y: center.y - diameter / 2,
                        width: diameter, height: diameter)
                    context.fill(Path(ellipseIn: circle), with: .color(palette.blob))
                }
                Text(letter)
                    // Artwork, so the letter scales with the tile, not Dynamic Type.
                    .font(.custom("Caprasimo-Regular", fixedSize: size.width * 0.55))
                    .foregroundStyle(Theme.Colors.posterTitle.opacity(0.92))
                    .position(x: size.width / 2, y: size.height * letterHeight)
            }
        }
        .clipped()
        .accessibilityHidden(true)
    }
}

/// Poster tile color pairs (from the theme), picked consistently from the title.
private enum PosterPalette {
    static func colors(for title: String) -> (base: Color, blob: Color) {
        let options = Theme.Colors.posterTiles
        // A simple stable hash. Swift's built-in hashValue changes every launch.
        let hash = title.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0x7FFF_FFFF }
        return options[hash % options.count]
    }
}

// MARK: - Shelf poster card

/// The shelf grid card: poster art with a dark fade, the format badge,
/// a check when reviewed, and the title and details along the bottom.
struct ShelfPosterCard: View {
    let title: String
    let letter: String
    /// e.g. "2005 · PG-13 · Plex" or "1999 · 2/5"
    let meta: String
    let format: MediaFormat
    let isReviewed: Bool
    /// Width ÷ height. The shelf grid uses 3:4.
    var aspectRatio: CGFloat = 3 / 4
    var titleSize: CGFloat = 20

    var body: some View {
        Color.clear
            .aspectRatio(aspectRatio, contentMode: .fit)
            .overlay {
                ZStack(alignment: .bottomLeading) {
                    PosterArt(title: title, letter: letter, letterHeight: 0.36)
                    posterFade
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(Theme.Fonts.heading(titleSize, relativeTo: .title3))
                            .foregroundStyle(Theme.Colors.posterTitle)
                            .lineLimit(3)
                            .minimumScaleFactor(0.7)
                        Text(meta)
                            .font(Theme.Fonts.body(13, relativeTo: .footnote))
                            .foregroundStyle(Theme.Colors.posterMeta)
                            .lineLimit(1)
                    }
                    .padding(12)
                }
            }
            .overlay(alignment: .topLeading) {
                FormatBadge(format: format).padding(10)
            }
            .overlay(alignment: .topTrailing) {
                if isReviewed {
                    ReviewedCheck().padding(10)
                }
            }
            .clipShape(.rect(cornerRadius: Theme.Radius.poster))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.poster)
                    .strokeBorder(Theme.Colors.divider)
            }
            // The card has a fixed shape, so text growth is capped to keep it readable.
            // VoiceOver still reads the full label below.
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityText)
    }

    /// The design's bottom-up dark gradient that keeps the title readable.
    private var posterFade: some View {
        LinearGradient(
            stops: [
                .init(color: Theme.Colors.posterInk.opacity(0.96), location: 0),
                .init(color: Theme.Colors.posterInk.opacity(0.55), location: 0.38),
                .init(color: Theme.Colors.posterInk.opacity(0), location: 0.65),
            ],
            startPoint: .bottom,
            endPoint: .top
        )
    }

    private var accessibilityText: String {
        var parts = [title, format.rawValue, meta]
        if isReviewed { parts.append("Reviewed") }
        return parts.joined(separator: ", ")
    }
}

/// The highlight-colored circle with a check, shown on reviewed titles.
struct ReviewedCheck: View {
    var body: some View {
        Image(systemName: "checkmark")
            .font(.system(size: 13, weight: .heavy))
            .foregroundStyle(Theme.Colors.onHighlight)
            .frame(width: 30, height: 30)
            .background(Theme.Colors.highlight, in: Circle())
            .accessibilityHidden(true)
    }
}

// MARK: - Previews

#Preview("Shelf cards") {
    LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible())], spacing: 14) {
        ShelfPosterCard(title: "Batman Begins", letter: "B", meta: "2005 · PG-13 · Plex", format: .digital, isReviewed: false)
        ShelfPosterCard(title: "The Phantom Menace", letter: "P", meta: "1999 · 2/5", format: .dvd, isReviewed: true)
        ShelfPosterCard(title: "Wonder Woman", letter: "W", meta: "2017 · PG-13 · Prime", format: .streaming, isReviewed: false)
        ShelfPosterCard(title: "Harry Potter and the Prisoner of Azkaban", letter: "H", meta: "2004 · PG", format: .dvd, isReviewed: false)
    }
    .padding(Theme.Spacing.page)
    .themedScreen()
}

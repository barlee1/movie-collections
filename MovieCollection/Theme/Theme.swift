//
//  Theme.swift
//  MovieCollection
//
//  Purpose: Design tokens from the "Organic" design system (colors, fonts,
//  spacing, radii, shadows) so every view pulls its look from one place.
//  Used in: All views.
//

import SwiftUI

enum Theme {

    // MARK: - Colors

    enum Colors {

        // MARK: Brand palette
        // The app's only color values. Change these five to re-theme everything;
        // every other color below is derived from them.

        /// Light pink: page and card backgrounds, poster text.
        static let main = Color(hex: 0xD79BAC)
        /// Peach: tinted fills (review cards, search panel), stars, poster tiles.
        static let main2 = Color(hex: 0xDE928A)
        /// Dark green: buttons, selected chips, links, friend cards.
        static let secondary = Color(hex: 0x134B40)
        /// Dark purple: text, the tab bar, the second button style.
        static let secondary2 = Color(hex: 0x581D34)
        /// Yellow: the pop color (active tab, reviewed check, badges, profile ring).
        static let accent = Color(hex: 0xF8CB00)

        // MARK: Page

        static let background = lighten(main, 0.86)
        /// Raised fills: cards, unselected chips, the search bar.
        static let surface = lighten(main, 0.68)
        static let text = secondary2
        /// Secondary text, still readable on the page background.
        static let textMuted = lighten(secondary2, 0.22)
        /// Placeholder text in fields.
        static let textPlaceholder = lighten(secondary2, 0.45)
        /// Hairline borders.
        static let divider = secondary2.opacity(0.18)
        /// Dims the page behind the search panel.
        static let backdrop = secondary2.opacity(0.3)
        /// The ink soft shadows are tinted with.
        static let shadow = secondary2

        // MARK: Actions

        /// Primary buttons and selected chips.
        static let action = secondary
        static let actionPressed = darken(secondary, 0.25)
        /// Text and icons on `action`.
        static let onAction = background
        /// The second button style ("See what your friends are watching").
        static let actionAlt = secondary2
        static let actionAltPressed = darken(secondary2, 0.3)
        static let onActionAlt = background
        /// Links and text-only buttons.
        static let link = secondary
        /// Validation hints and errors.
        static let error = darken(main2, 0.45)

        // MARK: Highlights

        /// The pop color.
        static let highlight = accent
        /// Text and icons on `highlight`.
        static let onHighlight = secondary2

        // MARK: Tints

        /// Light peach fills: review cards, search panel, icon circles.
        static let tintMain = lighten(main2, 0.72)
        /// Light green fills: profile stat cards, streaming tags.
        static let tintSecondary = lighten(secondary, 0.86)
        /// Near-white fills: neutral tags.
        static let tintNeutral = lighten(main, 0.94)

        // MARK: Stars

        /// Filled stars on light backgrounds.
        static let star = darken(main2, 0.25)
        /// Empty stars on light backgrounds.
        static let starOff = main2
        /// Filled stars on dark cards.
        static let starOnDark = accent
        /// Empty stars on dark cards.
        static let starOffOnDark = lighten(secondary, 0.35)

        // MARK: Tab bar

        static let navBar = secondary2
        static let navBarContent = background
        static let navBarActive = accent
        static let navBarActiveContent = secondary2

        // MARK: Dark cards (friends' reviews)

        static let darkCard = secondary
        static let onDarkCard = background
        static let onDarkCardMuted = lighten(secondary, 0.75)

        // MARK: Posters

        /// The dark ink the poster fade and owned-format badge are built from.
        static let posterInk = darken(secondary2, 0.55)
        /// Title text on the poster fade.
        static let posterTitle = lighten(main, 0.9)
        /// Detail text on the poster fade.
        static let posterMeta = lighten(main, 0.7)
        /// The badge behind "STREAMING" on a poster.
        static let badgeStreaming = secondary
        /// Tile and corner-circle color pairs for placeholder posters.
        static let posterTiles: [(base: Color, blob: Color)] = [
            (secondary, lighten(secondary, 0.15)),
            (secondary2, lighten(secondary2, 0.15)),
            (darken(main2, 0.3), darken(main2, 0.15)),
            (darken(main, 0.35), darken(main, 0.2)),
            (darken(accent, 0.45), darken(accent, 0.3)),
            (secondary.mix(with: secondary2, by: 0.5), lighten(secondary.mix(with: secondary2, by: 0.5), 0.15)),
        ]

        // MARK: User tags

        /// Fill and text pairs for user-made tags, one per brand color.
        static let tagColors: [(fill: Color, text: Color)] = [
            (lighten(main, 0.55), darken(secondary2, 0.1)),
            (lighten(main2, 0.55), darken(main2, 0.6)),
            (lighten(secondary, 0.8), secondary),
            (lighten(secondary2, 0.8), secondary2),
            (lighten(accent, 0.6), darken(accent, 0.65)),
        ]

        // MARK: Helpers

        /// Mixes a color toward white. 0 keeps it, 1 is white.
        private static func lighten(_ color: Color, _ amount: Double) -> Color {
            color.mix(with: .white, by: amount)
        }

        /// Mixes a color toward black. 0 keeps it, 1 is black.
        private static func darken(_ color: Color, _ amount: Double) -> Color {
            color.mix(with: .black, by: amount)
        }
    }

    // MARK: - Fonts

    enum Fonts {
        /// Caprasimo display face for headings and card titles.
        /// `relativeTo` keeps it scaling with the user's Dynamic Type setting.
        static func heading(_ size: CGFloat, relativeTo style: Font.TextStyle = .title) -> Font {
            .custom("Caprasimo-Regular", size: size, relativeTo: style)
        }

        /// Figtree body face. Only the weights bundled with the app are offered.
        static func body(_ size: CGFloat, weight: BodyWeight = .regular, relativeTo style: Font.TextStyle = .body) -> Font {
            .custom(weight.fontName, size: size, relativeTo: style)
        }

        enum BodyWeight {
            case regular, semibold, bold

            var fontName: String {
                switch self {
                case .regular: "Figtree-Regular"
                case .semibold: "Figtree-SemiBold"
                case .bold: "Figtree-Bold"
                }
            }
        }
    }

    // MARK: - Spacing (design density is 1.10x)

    enum Spacing {
        static let xs: CGFloat = 4.4
        static let sm: CGFloat = 8.8
        static let md: CGFloat = 13.2
        static let lg: CGFloat = 17.6
        static let xl: CGFloat = 26.4
        static let xxl: CGFloat = 35.2
        /// Standard horizontal page padding used by most screens.
        static let page: CGFloat = 20
    }

    // MARK: - Corner radii

    enum Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 28
        /// Cards are over-rounded: radius-lg x 1.15.
        static let card: CGFloat = 32.2
        /// Poster tiles on the shelf grid.
        static let poster: CGFloat = 20
    }

    // MARK: - Shadows

    /// Soft ink-tinted shadows. CSS blur is roughly twice SwiftUI's radius.
    enum Shadow {
        case sm, md, lg

        var color: Color {
            switch self {
            case .sm: Colors.shadow.opacity(0.14)
            case .md: Colors.shadow.opacity(0.16)
            case .lg: Colors.shadow.opacity(0.22)
            }
        }

        var radius: CGFloat {
            switch self {
            case .sm: 1
            case .md: 5
            case .lg: 16
            }
        }

        var y: CGFloat {
            switch self {
            case .sm: 1
            case .md: 3
            case .lg: 12
            }
        }
    }
}

// MARK: - View helpers

extension View {
    /// Applies one of the design system's elevation shadows.
    func themeShadow(_ shadow: Theme.Shadow) -> some View {
        self.shadow(color: shadow.color, radius: shadow.radius, x: 0, y: shadow.y)
    }

    /// The design's "washed" photo treatment: desaturated, softer, and lifted
    /// so images sit back into the warm page.
    func washed() -> some View {
        self
            .saturation(0.6)
            .contrast(0.85)
            .brightness(0.1)
            .opacity(0.94)
    }
}

// MARK: - Hex colors

extension Color {
    /// Creates an opaque sRGB color from a hex value like 0xC67139.
    init(hex: UInt32) {
        // Assigning to `self` (rather than delegating with `self.init`) keeps
        // Xcode Previews happy, since it wraps expressions in this file.
        self = Color(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

// MARK: - Previews

#Preview("Theme tokens") {
    ScrollView {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            Text("Your shelf")
                .font(Theme.Fonts.heading(40, relativeTo: .largeTitle))
            Text("Figtree regular body text")
                .font(Theme.Fonts.body(15))
            Text("Figtree semibold")
                .font(Theme.Fonts.body(15, weight: .semibold))
            Text("Figtree bold")
                .font(Theme.Fonts.body(15, weight: .bold))

            HStack(spacing: Theme.Spacing.sm) {
                ForEach(
                    [
                        Theme.Colors.main, Theme.Colors.main2, Theme.Colors.secondary,
                        Theme.Colors.secondary2, Theme.Colors.accent, Theme.Colors.background,
                    ], id: \.self
                ) { color in
                    Circle()
                        .fill(color)
                        .frame(width: 40, height: 40)
                        .overlay(Circle().stroke(Theme.Colors.divider))
                }
            }

            Image("EllaProfile")
                .resizable()
                .scaledToFill()
                .frame(width: 104, height: 104)
                .washed()
                .clipShape(Circle())
                // 6pt ring outside the photo, matching the design's box-shadow ring.
                .padding(6)
                .background(Theme.Colors.highlight, in: Circle())

            Text("Card")
                .font(Theme.Fonts.heading(17, relativeTo: .headline))
                .padding(Theme.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.Colors.surface, in: .rect(cornerRadius: Theme.Radius.card))
                .themeShadow(.md)
        }
        .padding(Theme.Spacing.page)
    }
    .foregroundStyle(Theme.Colors.text)
    .background(Theme.Colors.background)
}

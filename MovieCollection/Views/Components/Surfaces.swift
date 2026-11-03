//
//  Surfaces.swift
//  MovieCollection
//
//  Purpose: The design's over-rounded card surface, uppercase section
//  labels, and pill-shaped text fields.
//  Used in: Review cards, profile stats, Add options, filters, forms.
//

import SwiftUI

// MARK: - Card

extension View {
    /// The design's card: a filled, over-rounded surface.
    /// - Parameters:
    ///   - background: Fill color. Defaults to the sand surface.
    ///   - padding: Inner padding. The design's default is 13.2pt.
    ///   - bordered: Adds a hairline border (used on the Add options).
    func cardStyle(
        background: Color = Theme.Colors.surface,
        padding: CGFloat = Theme.Spacing.md,
        bordered: Bool = false
    ) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background, in: .rect(cornerRadius: Theme.Radius.card))
            .overlay {
                if bordered {
                    RoundedRectangle(cornerRadius: Theme.Radius.card)
                        .strokeBorder(Theme.Colors.divider)
                }
            }
    }
}

// MARK: - Section label

/// Small uppercase, letter-spaced label above a group of options,
/// e.g. "MOOD" or "FORMAT".
struct SectionLabel: View {
    let text: String
    var size: CGFloat = 13

    var body: some View {
        Text(text.uppercased())
            .font(Theme.Fonts.body(size, weight: .bold, relativeTo: .caption))
            .tracking(size * 0.12)
            .foregroundStyle(Theme.Colors.textMuted)
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Pill text field

extension View {
    /// Styles a TextField as the design's pill input: page-colored fill,
    /// hairline border, 44pt tall.
    func pillField() -> some View {
        self
            .font(Theme.Fonts.body(15))
            .foregroundStyle(Theme.Colors.text)
            .tint(Theme.Colors.action)
            .padding(.horizontal, 16)
            .frame(minHeight: 44)
            .background(Theme.Colors.background, in: Capsule())
            .overlay {
                Capsule().strokeBorder(Theme.Colors.divider)
            }
    }
}

// MARK: - Previews

#Preview {
    @Previewable @State var actor = ""
    VStack(alignment: .leading, spacing: 18) {
        VStack(alignment: .leading, spacing: 4) {
            Text("154")
                .font(Theme.Fonts.heading(32))
                .foregroundStyle(Theme.Colors.secondary)
            Text("Movies").font(Theme.Fonts.body(14))
        }
        .cardStyle(background: Theme.Colors.tintSecondary)

        VStack(alignment: .leading, spacing: 4) {
            Text("Type it in").font(Theme.Fonts.heading(21))
            Text("Add a single film by hand.")
                .font(Theme.Fonts.body(14))
                .foregroundStyle(Theme.Colors.textMuted)
        }
        .cardStyle(padding: 20, bordered: true)

        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Actor", size: 12)
            TextField("e.g. Sandra Bullock", text: $actor)
                .pillField()
        }
    }
    .padding(Theme.Spacing.page)
    .themedScreen()
}

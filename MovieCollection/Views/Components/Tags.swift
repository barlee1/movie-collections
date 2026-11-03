//
//  Tags.swift
//  MovieCollection
//
//  Purpose: Small pill labels tinted from the color ramps, the dark format
//  badge used on posters, and the icon/style each format uses.
//  Used in: Shelf cards, movie detail, profile, review states.
//

import SwiftUI

// MARK: - Tag

struct TagView: View {
    enum Style {
        /// Light peach tint with text-colored words.
        case main
        /// Light green tint with dark green words.
        case secondary
        /// Near-white tint with text-colored words.
        case neutral
        /// Outline in the action color, no fill.
        case outline
    }

    enum Size {
        /// 13pt text, used inline (location tags).
        case regular
        /// 14pt text, used for standalone tags (review state, services).
        case large

        var fontSize: CGFloat { self == .regular ? 13 : 14 }
        var verticalPadding: CGFloat { self == .regular ? 5 : 6 }
        var horizontalPadding: CGFloat { self == .regular ? 12 : 14 }
    }

    let text: String
    var style: Style = .main
    var size: Size = .regular
    /// Optional SF Symbol shown before the text.
    var systemImage: String? = nil

    var body: some View {
        HStack(spacing: 5) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: size.fontSize - 1, weight: .bold))
                    .accessibilityHidden(true)
            }
            Text(text)
                .font(Theme.Fonts.body(size.fontSize, relativeTo: .footnote))
                .tracking(0.26)
                // Keep words whole; wrapping rows move the whole tag instead.
                .lineLimit(1)
        }
        .foregroundStyle(foreground)
        .padding(.vertical, size.verticalPadding)
        .padding(.horizontal, size.horizontalPadding)
        .background(background, in: Capsule())
        .overlay {
            if style == .outline {
                Capsule().strokeBorder(Theme.Colors.action)
            }
        }
    }

    private var foreground: Color {
        switch style {
        case .main: Theme.Colors.text
        case .secondary: Theme.Colors.secondary
        case .neutral: Theme.Colors.text
        case .outline: Theme.Colors.action
        }
    }

    private var background: Color {
        switch style {
        case .main: Theme.Colors.tintMain
        case .secondary: Theme.Colors.tintSecondary
        case .neutral: Theme.Colors.tintNeutral
        case .outline: .clear
        }
    }
}

// MARK: - Format badge (on posters)

/// The small dark badge in a poster's top-left corner, e.g. "DVD".
struct FormatBadge: View {
    let format: MediaFormat

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: format.badgeSystemImage)
                .font(.system(size: 11, weight: .bold))
            Text(format.rawValue.uppercased())
                .font(Theme.Fonts.body(11, weight: .bold, relativeTo: .caption2))
                .tracking(0.88)
        }
        .foregroundStyle(Theme.Colors.posterTitle)
        .padding(.vertical, 5)
        .padding(.horizontal, 9)
        .background(background, in: .rect(cornerRadius: Theme.Radius.sm))
        .accessibilityHidden(true)
    }

    private var background: Color {
        format == .streaming ? Theme.Colors.badgeStreaming : Theme.Colors.posterInk.opacity(0.82)
    }
}

// MARK: - Format styling

extension MediaFormat {
    /// Passive icons that say where a title lives (a disc, the cloud, a TV),
    /// so none of them look like a download or play button.
    var systemImage: String {
        switch self {
        case .dvd: "opticaldisc"
        case .digital: "icloud"
        case .streaming: "tv"
        }
    }

    /// Filled versions for the small poster badges, which read better at 11pt.
    var badgeSystemImage: String {
        switch self {
        case .dvd: "opticaldisc.fill"
        case .digital: "icloud.fill"
        case .streaming: "tv.fill"
        }
    }

    /// Owned formats use the main tag; streaming uses the secondary tag.
    var tagStyle: TagView.Style {
        self == .streaming ? .secondary : .main
    }
}

// MARK: - Previews

#Preview {
    VStack(alignment: .leading, spacing: 14) {
        HStack {
            ForEach(MediaFormat.allCases) { format in
                TagView(text: format.locationLabel, style: format.tagStyle, systemImage: format.systemImage)
            }
        }
        HStack {
            TagView(text: "Amazon Prime", style: .neutral)
            TagView(text: "Tonight's pick", style: .main)
            TagView(text: "Outline", style: .outline)
        }
        TagView(text: "Not Reviewed Yet", style: .neutral, size: .large)
        TagView(text: "Last watched Sep 25, 2024", style: .secondary, size: .large, systemImage: "calendar")
        HStack {
            ForEach(MediaFormat.allCases) { FormatBadge(format: $0) }
        }
        .padding(10)
        .background(Theme.Colors.darkCard)
    }
    .padding(Theme.Spacing.page)
    .themedScreen()
}

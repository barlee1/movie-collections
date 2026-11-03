//
//  WatchProgressBar.swift
//  MovieCollection
//
//  Purpose: How much of the shelf the user has watched, e.g. "Watched 11 of 30",
//  as a rounded bar that animates as titles are checked off. Built as a
//  ProgressViewStyle, so VoiceOver reads it as a progress indicator.
//  Used in: ShelfView, ProfileView.
//

import SwiftUI

struct WatchProgressBar: View {
    let watched: Int
    let total: Int

    private var fraction: Double {
        total > 0 ? Double(watched) / Double(total) : 0
    }

    var body: some View {
        ProgressView(value: fraction) {
            HStack(alignment: .firstTextBaseline) {
                Text("Watched \(watched) of \(total)")
                    .font(Theme.Fonts.body(14, weight: .semibold, relativeTo: .subheadline))
                    .contentTransition(.numericText())
                Spacer()
                Text(fraction.formatted(.percent.precision(.fractionLength(0))))
                    .font(Theme.Fonts.body(13, relativeTo: .footnote))
                    .foregroundStyle(Theme.Colors.textMuted)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
        }
        .progressViewStyle(.pillBar)
        .animation(.snappy(duration: 0.4), value: watched)
        .animation(.snappy(duration: 0.4), value: total)
        .accessibilityLabel("Watched \(watched) of \(total) titles")
    }
}

/// A thick, fully rounded bar in the theme colors, with the label above it.
struct PillBarProgressStyle: ProgressViewStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            configuration.label
            GeometryReader { geometry in
                let fraction = min(max(configuration.fractionCompleted ?? 0, 0), 1)
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.Colors.tintMain)
                    Capsule()
                        .fill(Theme.Colors.action)
                        // Keep a visible sliver once anything is watched.
                        .frame(width: fraction > 0 ? max(geometry.size.width * fraction, 12) : 0)
                }
            }
            .frame(height: 12)
            .overlay {
                Capsule().strokeBorder(Theme.Colors.divider)
            }
        }
    }
}

extension ProgressViewStyle where Self == PillBarProgressStyle {
    static var pillBar: PillBarProgressStyle { PillBarProgressStyle() }
}

// MARK: - Previews

#Preview {
    @Previewable @State var watched = 11
    VStack(spacing: 24) {
        WatchProgressBar(watched: watched, total: 30)
        WatchProgressBar(watched: 0, total: 30)
        Button("Watch one more") { watched = min(watched + 1, 30) }
            .buttonStyle(.pill())
    }
    .padding(Theme.Spacing.page)
    .themedScreen()
}

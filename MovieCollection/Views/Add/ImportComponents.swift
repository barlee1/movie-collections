//
//  ImportComponents.swift
//  MovieCollection
//
//  Purpose: Pieces shared by the import screens: the sticky confirm bar and
//  the finished state.
//  Used in: SpreadsheetImportView, LetterboxdImportView.
//

import SwiftUI

/// The sticky bottom bar on an import preview, e.g. "Add 7 titles".
struct ImportActionBar: View {
    let title: String
    let isEnabled: Bool
    let action: () -> Void
    let startOver: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button("Start over", action: startOver)
                .buttonStyle(.pill(.secondary, typeface: .body, fontSize: 15, height: 50, fullWidth: false))
            Button(title, action: action)
                .buttonStyle(.pill(.primary, typeface: .body, fontSize: 16, height: 50))
                .disabled(!isEnabled)
        }
        .padding(.horizontal, Theme.Spacing.page)
        .padding(.vertical, 12)
        .background(Theme.Colors.background)
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.Colors.divider).frame(height: 1)
        }
    }
}

/// The finished state of an import, with a way back to the shelf.
struct ImportDoneView: View {
    let headline: String
    let message: String
    let startOver: () -> Void
    @Environment(AppRouter.self) private var router

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56, weight: .semibold))
                .foregroundStyle(Theme.Colors.onHighlight, Theme.Colors.highlight)
                .symbolEffect(.bounce, value: headline)
                .accessibilityHidden(true)
            Text(headline)
                .font(Theme.Fonts.heading(26, relativeTo: .title))
                .multilineTextAlignment(.center)
            Text(message)
                .font(Theme.Fonts.body(15))
                .foregroundStyle(Theme.Colors.textMuted)
                .multilineTextAlignment(.center)
            Button("See your shelf") { router.select(.shelf) }
                .buttonStyle(.pill(.primary))
                .padding(.top, 6)
            Button("Import another file", action: startOver)
                .buttonStyle(.pill(.secondary, typeface: .body, fontSize: 15, height: 46))
        }
        .frame(maxWidth: .infinity)
        .cardStyle(padding: 24, bordered: true)
    }
}

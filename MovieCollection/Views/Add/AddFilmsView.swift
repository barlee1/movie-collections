//
//  AddFilmsView.swift
//  MovieCollection
//
//  Purpose: The Add tab: four ways to add titles (scan, spreadsheet,
//  Letterboxd, or type it in), plus TMDB's required credit.
//  Used in: RootTabView (Add tab).
//

import SwiftUI

struct AddFilmsView: View {
    @Environment(AppRouter.self) private var router

    private struct Option: Identifiable {
        let title: String
        let body: String
        let systemImage: String
        let route: Route
        var id: String { title }
    }

    private let options: [Option] = [
        Option(
            title: "Scan a cover", body: "Point your camera at a case, or pick a photo. The title is read right on your phone.", systemImage: "text.viewfinder",
            route: .scanCover),
        Option(
            title: "Import a spreadsheet", body: "Bring in a whole collection from a CSV file in one go.", systemImage: "tablecells", route: .importSpreadsheet),
        Option(
            title: "Import from Letterboxd", body: "Bring your ratings and watch dates in for films you already own.", systemImage: "star",
            route: .importLetterboxd),
        Option(title: "Type it in", body: "Add a single film by hand.", systemImage: "pencil", route: .addTitle()),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScreenHeader(title: "Add films", subtitle: "Pick the quickest way to fill your shelf.")
                    .padding(.bottom, 4)
                ForEach(options) { option in
                    Button {
                        router.push(option.route)
                    } label: {
                        optionCard(option)
                    }
                    .buttonStyle(.pressableCard)
                }

                // TMDB's required credit, where its movie data is used.
                Text(AppInfo.tmdbCredit)
                    .font(Theme.Fonts.body(12, relativeTo: .caption))
                    .foregroundStyle(Theme.Colors.textMuted)
                    .padding(.top, 8)
            }
            .padding(.horizontal, Theme.Spacing.page)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .themedScreen()
    }

    private func optionCard(_ option: Option) -> some View {
        HStack(spacing: 16) {
            Image(systemName: option.systemImage)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Theme.Colors.text)
                .frame(width: 56, height: 56)
                .background(Theme.Colors.tintMain, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(option.title)
                    .font(Theme.Fonts.heading(21, relativeTo: .title3))
                    .foregroundStyle(Theme.Colors.text)
                Text(option.body)
                    .font(Theme.Fonts.body(14, relativeTo: .subheadline))
                    .foregroundStyle(Theme.Colors.textMuted)
                    .lineSpacing(2)
                    .multilineTextAlignment(.leading)
            }
        }
        .cardStyle(padding: 20, bordered: true)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

#Preview {
    NavigationStack {
        AddFilmsView()
    }
    .environment(AppRouter())
}

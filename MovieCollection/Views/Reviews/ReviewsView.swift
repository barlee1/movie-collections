//
//  ReviewsView.swift
//  MovieCollection
//
//  Purpose: The user's reviews, newest first. As a tab it has no back button;
//  pushed from a detail screen's "See Review" it adds one and scrolls to
//  that title's review.
//  Used in: RootTabView (Reviews tab and Route.reviews).
//

import SwiftData
import SwiftUI

struct ReviewsView: View {
    @Environment(AppViewModel.self) private var appModel
    @Environment(AppRouter.self) private var router

    /// Set when pushed from a detail screen: shows a back button and scrolls here.
    var highlightedTitleID: PersistentIdentifier? = nil

    var body: some View {
        let titles = appModel.reviewedTitles

        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if highlightedTitleID != nil {
                        BackButton()
                    }
                    ScreenHeader(title: "Your Reviews", titleSize: 34)
                        .padding(.top, highlightedTitleID == nil ? 8 : 0)

                    if titles.isEmpty {
                        Text("No reviews yet. Open a title and tap Edit to write one.")
                            .font(Theme.Fonts.body(15))
                            .foregroundStyle(Theme.Colors.textMuted)
                    }

                    ForEach(titles) { title in
                        if let review = title.review {
                            ReviewCard(title: title, review: review) {
                                router.push(.titleDetail(title.persistentModelID))
                            }
                            .id(title.persistentModelID)
                        }
                    }
                }
                .padding(.horizontal, Theme.Spacing.page)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .onAppear {
                if let highlightedTitleID {
                    proxy.scrollTo(highlightedTitleID, anchor: .top)
                }
            }
        }
        .themedScreen()
    }
}

/// One of the user's reviews: small poster, title, date, stars, and text.
private struct ReviewCard: View {
    let title: OwnedTitle
    let review: Review
    let openTitle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                Button(action: openTitle) {
                    PosterArt(title: title.title, letter: title.posterLetter)
                        .frame(width: 40, height: 56)
                        .clipShape(.rect(cornerRadius: Theme.Radius.sm))
                }
                .buttonStyle(.pressableCard)
                .accessibilityLabel("Open \(title.title)")

                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(title.title)
                            .font(Theme.Fonts.heading(17, relativeTo: .headline))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(review.date.displayText)
                            .font(Theme.Fonts.body(11, relativeTo: .caption2))
                            .foregroundStyle(Theme.Colors.textMuted)
                            .fixedSize()
                    }
                    StarRatingView(rating: review.rating)
                }
            }
            if !review.text.isEmpty {
                Text(review.text)
                    .font(Theme.Fonts.body(13, relativeTo: .footnote))
                    .lineSpacing(3)
            }
        }
        .cardStyle(background: Theme.Colors.tintMain)
    }
}

#Preview {
    let appModel = AppViewModel.preview()
    NavigationStack {
        ReviewsView()
    }
    .environment(appModel)
    .environment(AppRouter())
    .task { await appModel.start() }
}
